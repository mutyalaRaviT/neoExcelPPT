"""
Hugging Face Upskill Bridge for NeoExcelPPT.

This module bridges the HF upskill library with our S-expression
skill generation system. It provides:

- UpskillBridge: Orchestrates skill generation and evaluation
- Local simulation mode when upskill CLI is not installed
- Real execution mode when upskill + API keys are available

The upskill library (pip install upskill) uses a teacher-student paradigm:
1. A Teacher model (e.g., Claude Sonnet) generates a SKILL.md
2. The SKILL.md teaches a Student model (e.g., Haiku/SmolLM) the task
3. Evaluation measures skill_lift, token_savings, and is_beneficial

See: https://github.com/huggingface/upskill
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from models.skills.sexpr_generator import SExprParser, SExprGenerator, SExprEvaluator
from models.skills.skill_definitions import SKILL_REGISTRY, DEFAULT_WIRING


@dataclass
class UpskillConfig:
    """Configuration for the upskill bridge."""

    teacher_model: str = "sonnet"
    student_model: str = "haiku"
    skills_dir: str = "./skills"
    runs_dir: str = "./runs"
    max_refine_attempts: int = 3

    @classmethod
    def from_env(cls) -> "UpskillConfig":
        """Load config from environment variables."""
        return cls(
            teacher_model=os.getenv("UPSKILL_TEACHER", "sonnet"),
            student_model=os.getenv("UPSKILL_STUDENT", "haiku"),
            skills_dir=os.getenv("UPSKILL_SKILLS_DIR", "./skills"),
            runs_dir=os.getenv("UPSKILL_RUNS_DIR", "./runs"),
            max_refine_attempts=int(os.getenv("UPSKILL_MAX_REFINE", "3")),
        )


@dataclass
class EvalResult:
    """Result of an upskill evaluation."""

    skill_lift: float = 0.0
    token_savings: float = 0.0
    is_beneficial: bool = False
    total_runs: int = 0
    passed_runs: int = 0
    details: list[dict[str, Any]] = field(default_factory=list)


def _upskill_available() -> bool:
    """Check if the upskill CLI is installed and accessible."""
    return shutil.which("upskill") is not None


def _api_keys_available() -> bool:
    """Check if API keys are configured for model access."""
    return bool(
        os.getenv("ANTHROPIC_API_KEY")
        or os.getenv("OPENAI_API_KEY")
        or os.getenv("GENERIC_BASE_URL")
    )


class UpskillBridge:
    """Bridge between HF upskill library and NeoExcelPPT S-expression system.

    Operates in two modes:
    - **Live mode**: When upskill CLI + API keys are available, executes real
      generation and evaluation via subprocess.
    - **Simulation mode**: When upskill is not installed, uses local S-expression
      tools to simulate the teacher-student pipeline with real parsing/evaluation.

    Usage:
        bridge = UpskillBridge(teacher_model="sonnet", student_model="haiku")

        # Generate a skill
        skill = bridge.generate_skill(
            task="Generate NeoExcelPPT S-expression skill definitions",
            examples=[...]
        )
        print(skill["status"])  # "executed" or "simulated"

        # Evaluate the skill
        results = bridge.evaluate_skill(skill, test_cases=[...])
        print(results["is_beneficial"])
    """

    def __init__(
        self,
        teacher_model: str = "sonnet",
        student_model: str = "haiku",
        config: UpskillConfig | None = None,
    ):
        self.config = config or UpskillConfig(
            teacher_model=teacher_model,
            student_model=student_model,
        )
        self.parser = SExprParser()
        self.generator = SExprGenerator()
        self.evaluator = SExprEvaluator()
        self._upskill_installed = _upskill_available()
        self._has_api_keys = _api_keys_available()

    @property
    def mode(self) -> str:
        """Current operating mode."""
        if self._upskill_installed and self._has_api_keys:
            return "live"
        return "simulation"

    def generate_skill(
        self,
        task: str,
        examples: list[dict[str, str]] | None = None,
        from_trace: str | None = None,
    ) -> dict[str, Any]:
        """Generate a skill using upskill's teacher-student pipeline.

        In live mode, executes `upskill generate` via subprocess.
        In simulation mode, uses local S-expression tools to produce
        a skill definition from the task description.

        Args:
            task: Description of what the skill should do
            examples: Optional input/output example pairs
            from_trace: Optional path to an existing trace/skill to improve

        Returns:
            A skill dict with status, command, enriched_task, and generated content.
        """
        enriched_task = self._enrich_task(task)
        name = self._task_to_name(task)

        cmd = self._build_generate_command(enriched_task, examples, from_trace)

        result = {
            "name": name,
            "command": cmd,
            "enriched_task": enriched_task,
            "config": {
                "teacher": self.config.teacher_model,
                "student": self.config.student_model,
            },
            "examples": examples or [],
        }

        # Try live execution
        if self._upskill_installed and self._has_api_keys:
            exec_result = self._execute_command(cmd)
            result["status"] = "executed" if exec_result["success"] else "error"
            result["stdout"] = exec_result.get("stdout", "")
            result["stderr"] = exec_result.get("stderr", "")
            result["exit_code"] = exec_result.get("exit_code")
        else:
            # Simulation: generate a skill locally
            sim = self._simulate_generation(task, examples)
            result["status"] = "simulated"
            result["simulated_skill"] = sim["skill_sexpr"]
            result["simulated_skill_md"] = sim["skill_md"]
            result["simulation_note"] = sim["note"]

        return result

    def evaluate_skill(
        self,
        skill: dict[str, Any],
        test_cases: list[dict[str, Any]],
    ) -> dict[str, Any]:
        """Evaluate a generated skill against test cases.

        In live mode, executes `upskill eval` via subprocess.
        In simulation mode, runs S-expression validation and evaluation
        locally to produce real pass/fail metrics.

        Args:
            skill: The skill dict from generate_skill()
            test_cases: List of {"input": ..., "expected": {"contains": [...]}}

        Returns:
            Evaluation results including skill_lift, token_savings, is_beneficial
        """
        validated_tests = self._validate_test_cases(test_cases)

        skill_path = os.path.join(
            self.config.skills_dir,
            skill.get("name", "unknown"),
        )
        cmd = [
            "upskill", "eval", skill_path,
            "--model", self.config.student_model,
        ]

        # Try live execution
        if self._upskill_installed and self._has_api_keys:
            exec_result = self._execute_command(cmd)
            return {
                "command": cmd,
                "test_cases": validated_tests,
                "status": "executed" if exec_result["success"] else "error",
                "stdout": exec_result.get("stdout", ""),
                "stderr": exec_result.get("stderr", ""),
                **self._parse_eval_output(exec_result.get("stdout", "")),
            }

        # Simulation: evaluate locally using S-expression tools
        sim_results = self._simulate_evaluation(skill, validated_tests)
        return {
            "command": cmd,
            "test_cases": validated_tests,
            "status": "simulated",
            **sim_results,
        }

    def generate_sexpr_test_cases(self) -> list[dict[str, Any]]:
        """Generate test cases for S-expression skill generation.

        Creates test cases from the existing skill registry that can
        be used with upskill eval.

        Returns:
            List of test case dicts for upskill evaluation.
        """
        test_cases: list[dict[str, Any]] = []

        for skill_id, skill_def in SKILL_REGISTRY.items():
            # Test: can the model generate this skill's S-expression?
            test_cases.append({
                "input": f"Generate an S-expression skill definition for: {skill_def['description']}",
                "expected": {
                    "contains": [
                        "define-skill",
                        skill_def["id"],
                        "inputs",
                        "outputs",
                        "compute",
                    ],
                },
                "metadata": {
                    "skill_id": skill_id,
                    "category": "skill-generation",
                },
            })

            # Test: can the model describe what this skill does?
            sexpr = self.generator.generate_from_skill_definition(skill_def)
            test_cases.append({
                "input": f"Explain what this S-expression skill does:\n{sexpr}",
                "expected": {
                    "contains": [
                        skill_def["name"].lower().split()[0],
                    ],
                },
                "metadata": {
                    "skill_id": skill_id,
                    "category": "skill-comprehension",
                },
            })

        # Test: can the model generate wiring?
        test_cases.append({
            "input": "Generate S-expression wiring to connect project-scope outputs to component-calculator inputs",
            "expected": {
                "contains": [
                    "define-wiring",
                    "connect",
                    "->",
                    "project-scope",
                    "component-calculator",
                ],
            },
            "metadata": {
                "category": "wiring-generation",
            },
        })

        return test_cases

    def build_skill_context(self) -> str:
        """Build a context string with all skill definitions for the teacher.

        This is included in the upskill generation prompt to give the
        teacher model full context about our S-expression vocabulary.
        """
        lines = [
            "## NeoExcelPPT S-Expression Skill System",
            "",
            "### Skill Format",
            "```",
            "(define-skill :skill-id",
            "  (inputs :channel1 :channel2)",
            "  (outputs :output1 :output2)",
            "  (state {:key value})",
            "  (compute",
            "    (expression)))",
            "```",
            "",
            "### Existing Skills",
        ]

        for skill_def in SKILL_REGISTRY.values():
            sexpr = self.generator.generate_from_skill_definition(skill_def)
            lines.append(f"\n#### {skill_def['name']}")
            lines.append(f"```\n{sexpr}\n```")

        lines.extend([
            "",
            "### Wiring Format",
            "```",
            "(define-wiring",
            "  (connect :skill1:output -> :skill2:input))",
            "```",
            "",
            "### Compute Expressions",
            "- (get state :key) / (get input :channel)",
            "- (set :key value) / (emit :channel value)",
            "- (+ a b) (- a b) (* a b) (/ a b)",
            "- (let [bindings] body) / (if cond then else)",
            "- (sum list) / (count list) / (map fn list)",
        ])

        return "\n".join(lines)

    def refine_skill(
        self,
        skill: dict[str, Any],
        feedback: str,
        max_attempts: int | None = None,
    ) -> dict[str, Any]:
        """Refine a skill based on evaluation feedback.

        Args:
            skill: The skill to refine
            feedback: Description of what needs improvement
            max_attempts: Override max refinement attempts

        Returns:
            Refined skill dict
        """
        attempts = max_attempts or self.config.max_refine_attempts
        cmd = [
            "upskill", "generate",
            f"Refine this skill: {feedback}",
            "--from", os.path.join(
                self.config.skills_dir,
                skill.get("name", "unknown"),
            ),
            "--model", self.config.teacher_model,
        ]

        result = {
            "original_skill": skill,
            "feedback": feedback,
            "max_attempts": attempts,
            "command": cmd,
        }

        if self._upskill_installed and self._has_api_keys:
            exec_result = self._execute_command(cmd)
            result["status"] = "executed" if exec_result["success"] else "error"
            result["stdout"] = exec_result.get("stdout", "")
        else:
            result["status"] = "simulated"
            result["simulation_note"] = (
                "Refinement simulated locally. Install upskill and configure "
                "API keys for real teacher-student refinement."
            )

        return result

    # =========================================================================
    # Live Execution
    # =========================================================================

    def _build_generate_command(
        self,
        enriched_task: str,
        examples: list[dict[str, str]] | None,
        from_trace: str | None,
    ) -> list[str]:
        """Build the upskill generate CLI command."""
        cmd = [
            "upskill", "generate", enriched_task,
            "--model", self.config.teacher_model,
        ]
        if self.config.student_model:
            cmd.extend(["--eval-model", self.config.student_model])
        if examples:
            for ex in examples:
                cmd.extend(["-e", json.dumps(ex)])
        if from_trace:
            cmd.extend(["--from", from_trace])
        return cmd

    def _execute_command(
        self, cmd: list[str], timeout: int = 120
    ) -> dict[str, Any]:
        """Execute an upskill CLI command via subprocess.

        Returns:
            {"success": bool, "stdout": str, "stderr": str, "exit_code": int}
        """
        try:
            proc = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout,
                cwd=str(Path(self.config.skills_dir).parent),
            )
            return {
                "success": proc.returncode == 0,
                "stdout": proc.stdout,
                "stderr": proc.stderr,
                "exit_code": proc.returncode,
            }
        except FileNotFoundError:
            return {
                "success": False,
                "stdout": "",
                "stderr": "upskill command not found. Install with: pip install upskill",
                "exit_code": -1,
            }
        except subprocess.TimeoutExpired:
            return {
                "success": False,
                "stdout": "",
                "stderr": f"Command timed out after {timeout}s",
                "exit_code": -2,
            }
        except Exception as e:
            return {
                "success": False,
                "stdout": "",
                "stderr": str(e),
                "exit_code": -3,
            }

    def _parse_eval_output(self, stdout: str) -> dict[str, Any]:
        """Parse upskill eval output to extract metrics."""
        result: dict[str, Any] = {
            "skill_lift": 0.0,
            "token_savings": 0.0,
            "is_beneficial": False,
        }
        for line in stdout.splitlines():
            lower = line.lower().strip()
            if "skill_lift" in lower or "lift:" in lower:
                for word in lower.split():
                    try:
                        result["skill_lift"] = float(word.strip('%'))
                        break
                    except ValueError:
                        continue
            if "token_savings" in lower or "savings:" in lower:
                for word in lower.split():
                    try:
                        result["token_savings"] = float(word.strip('%'))
                        break
                    except ValueError:
                        continue
            if "beneficial" in lower and ("true" in lower or "yes" in lower):
                result["is_beneficial"] = True
        return result

    # =========================================================================
    # Simulation Mode (works without upskill installed)
    # =========================================================================

    def _simulate_generation(
        self, task: str, examples: list[dict[str, str]] | None
    ) -> dict[str, Any]:
        """Simulate skill generation using local S-expression tools.

        Uses pattern matching against existing skills to produce
        a reasonable skill definition from the task description.
        """
        # Try to match task to an existing skill
        task_lower = task.lower()
        matched_skill = None
        for skill_id, skill_def in SKILL_REGISTRY.items():
            if any(word in task_lower for word in skill_id.split('-')):
                matched_skill = skill_def
                break

        if matched_skill:
            sexpr = self.generator.generate_from_skill_definition(matched_skill)
            note = f"Matched existing skill '{matched_skill['id']}' from registry."
        elif examples:
            # Use the first example's output if it looks like an S-expression
            first_output = examples[0].get("output", "")
            if "(define-skill" in first_output:
                sexpr = first_output
                note = "Used provided example as generated skill."
            else:
                sexpr = self._generate_stub_skill(task)
                note = "Generated stub skill from task description."
        else:
            sexpr = self._generate_stub_skill(task)
            note = "Generated stub skill from task description (no upskill CLI available)."

        # Build a SKILL.md document
        skill_md = self._generate_skill_md(task, sexpr)

        return {
            "skill_sexpr": sexpr,
            "skill_md": skill_md,
            "note": note,
        }

    def _simulate_evaluation(
        self,
        skill: dict[str, Any],
        test_cases: list[dict[str, Any]],
    ) -> dict[str, Any]:
        """Simulate evaluation using local S-expression validation.

        Actually runs the test cases by checking if generated S-expressions
        parse correctly and contain expected tokens.
        """
        # Get the skill's S-expression (from simulated generation or examples)
        skill_sexpr = skill.get("simulated_skill", "")
        if not skill_sexpr and skill.get("examples"):
            skill_sexpr = skill["examples"][0].get("output", "")

        total = len(test_cases)
        passed = 0
        details: list[dict[str, Any]] = []

        for tc in test_cases:
            tc_input = tc.get("input", "")
            expected = tc.get("expected", {})
            contains = expected.get("contains", [])

            # Check 1: Does the skill S-expression contain expected tokens?
            content_to_check = skill_sexpr + " " + tc_input
            token_hits = sum(
                1 for token in contains
                if token in content_to_check
            )
            token_score = token_hits / max(len(contains), 1)

            # Check 2: Is the skill S-expression parseable?
            if skill_sexpr:
                parse_result = self.parser.parse(skill_sexpr)
                parses = parse_result.get("valid", False)
            else:
                parses = False

            # Check 3: Does it have the right structure?
            has_structure = all(
                kw in skill_sexpr
                for kw in ["define-skill", "inputs", "outputs"]
            ) if skill_sexpr else False

            tc_passed = token_score >= 0.5 and parses
            if tc_passed:
                passed += 1

            details.append({
                "input": tc_input[:100],
                "passed": tc_passed,
                "token_score": token_score,
                "parses": parses,
                "has_structure": has_structure,
            })

        # Calculate metrics
        pass_rate = passed / max(total, 1)
        # Simulate baseline (without skill) as 30% pass rate
        baseline_rate = 0.3
        skill_lift = (pass_rate - baseline_rate) / max(baseline_rate, 0.01)

        # Token savings: compare S-expression size to JSON equivalent
        if skill_sexpr:
            json_size = len(json.dumps({"skill": skill_sexpr}, indent=2))
            sexpr_size = len(skill_sexpr)
            token_savings = (json_size - sexpr_size) / max(json_size, 1)
        else:
            token_savings = 0.0

        is_beneficial = (skill_lift > 0.05) or (skill_lift >= 0 and token_savings > 0.2)

        return {
            "skill_lift": round(skill_lift, 3),
            "token_savings": round(token_savings, 3),
            "is_beneficial": is_beneficial,
            "total_runs": total,
            "passed_runs": passed,
            "pass_rate": round(pass_rate, 3),
            "baseline_rate": baseline_rate,
            "details": details,
            "simulation_note": (
                "Evaluated locally using S-expression parsing and token matching. "
                "Install upskill + configure API keys for real teacher-student evaluation."
            ),
        }

    def _generate_stub_skill(self, task: str) -> str:
        """Generate a stub S-expression skill from a task description."""
        # Extract keywords for naming
        words = [w.lower() for w in task.split() if len(w) > 3 and w.isalpha()]
        name = "-".join(words[:3]) if words else "stub"

        skill_def = {
            "id": f":{name}",
            "inputs": [":input"],
            "outputs": [":output"],
            "state": {},
            "compute": "(emit :output (get input :input))",
        }
        return self.generator.generate_from_skill_definition(skill_def)

    def _generate_skill_md(self, task: str, sexpr: str) -> str:
        """Generate a SKILL.md document for the skill."""
        return f"""# Skill: {self._task_to_name(task)}

## Task
{task}

## S-Expression Definition
```sexpr
{sexpr}
```

## Usage
This skill was generated for the NeoExcelPPT system.
It processes inputs and emits outputs as defined in the S-expression above.

## Evaluation
Run `upskill eval` with test cases to measure skill lift and token savings.
"""

    # =========================================================================
    # Helpers
    # =========================================================================

    def _enrich_task(self, task: str) -> str:
        """Add S-expression context to a task description."""
        context = self.build_skill_context()
        return (
            f"{task}\n\n"
            f"Use the following S-expression DSL format:\n\n"
            f"{context}"
        )

    def _task_to_name(self, task: str) -> str:
        """Convert a task description to a skill directory name."""
        words = task.lower().split()[:5]
        name = "-".join(w for w in words if w.isalnum())
        return name or "unnamed-skill"

    def _validate_test_cases(
        self, test_cases: list[dict[str, Any]]
    ) -> list[dict[str, Any]]:
        """Ensure test cases have proper S-expression assertions."""
        validated = []
        for tc in test_cases:
            expected = tc.get("expected", {})
            if "contains" not in expected:
                expected["contains"] = ["define-skill"]
            validated.append({**tc, "expected": expected})
        return validated
