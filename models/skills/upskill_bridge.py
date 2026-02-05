"""
Hugging Face Upskill Bridge for NeoExcelPPT.

This module bridges the HF upskill library with our S-expression
skill generation system. It provides:

- UpskillBridge: Orchestrates skill generation and evaluation
- generate_sexpr_skill: Generate S-expr skills via upskill pipeline
- evaluate_sexpr_skill: Evaluate generated S-exprs for quality

The upskill library (pip install upskill) uses a teacher-student paradigm:
1. A Teacher model (e.g., Claude Sonnet) generates a SKILL.md
2. The SKILL.md teaches a Student model (e.g., Haiku/SmolLM) the task
3. Evaluation measures skill_lift, token_savings, and is_beneficial

See: https://github.com/huggingface/upskill
"""

from __future__ import annotations

import json
import os
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from models.skills.sexpr_generator import SExprParser, SExprGenerator
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


class UpskillBridge:
    """Bridge between HF upskill library and NeoExcelPPT S-expression system.

    Usage:
        bridge = UpskillBridge(teacher_model="sonnet", student_model="haiku")

        # Generate a skill for S-expression creation
        skill = bridge.generate_skill(
            task="Generate NeoExcelPPT S-expression skill definitions",
            examples=[...]
        )

        # Evaluate the skill
        results = bridge.evaluate_skill(skill, test_cases=[...])
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

    def generate_skill(
        self,
        task: str,
        examples: list[dict[str, str]] | None = None,
        from_trace: str | None = None,
    ) -> dict[str, Any]:
        """Generate a skill using upskill's teacher-student pipeline.

        This wraps the `upskill generate` CLI command and enriches
        the task with our S-expression context.

        Args:
            task: Description of what the skill should do
            examples: Optional input/output example pairs
            from_trace: Optional path to an existing trace/skill to improve

        Returns:
            A skill dict with 'name', 'body', 'path', and 'metadata'
        """
        # Build the enriched task description with S-expr context
        enriched_task = self._enrich_task(task)

        # Build the upskill generate command
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

        # Return the command structure (actual execution requires API keys)
        return {
            "name": self._task_to_name(task),
            "command": cmd,
            "enriched_task": enriched_task,
            "config": {
                "teacher": self.config.teacher_model,
                "student": self.config.student_model,
            },
            "examples": examples or [],
            "status": "ready",
        }

    def evaluate_skill(
        self,
        skill: dict[str, Any],
        test_cases: list[dict[str, Any]],
    ) -> dict[str, Any]:
        """Evaluate a generated skill against test cases.

        This wraps `upskill eval` and adds S-expression validation.

        Args:
            skill: The skill dict from generate_skill()
            test_cases: List of {"input": ..., "expected": {"contains": [...]}}

        Returns:
            Evaluation results including skill_lift, token_savings, is_beneficial
        """
        # Validate test cases contain S-expression assertions
        validated_tests = self._validate_test_cases(test_cases)

        # Build the eval command
        skill_path = os.path.join(
            self.config.skills_dir,
            skill.get("name", "unknown"),
        )
        cmd = [
            "upskill", "eval", skill_path,
            "--model", self.config.student_model,
        ]

        return {
            "command": cmd,
            "test_cases": validated_tests,
            "skill_lift": 0.0,
            "token_savings": 0.0,
            "is_beneficial": False,
            "status": "ready",
            "note": "Execute command with API keys configured to get real results",
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
                        skill_def["name"].lower().split()[0],  # at least the first word
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
        return {
            "original_skill": skill,
            "feedback": feedback,
            "max_attempts": attempts,
            "command": [
                "upskill", "generate",
                f"Refine this skill: {feedback}",
                "--from", os.path.join(
                    self.config.skills_dir,
                    skill.get("name", "unknown"),
                ),
                "--model", self.config.teacher_model,
            ],
            "status": "ready",
        }

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
        # Take first few words, lowercase, hyphenate
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
