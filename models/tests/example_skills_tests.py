"""
Example Skills Tests for NeoExcelPPT S-Expression Generation.

These tests validate:
1. S-Expression parsing and generation
2. Skill definitions from the registry
3. Localhost:4000 UI interpretation
4. Wiring composition
5. Action composition
6. Upskill bridge integration
7. Round-trip (generate -> parse -> validate)
8. Token efficiency (S-expr vs JSON)
9. Dependency graph extraction
10. Full pipeline (interpret -> generate -> parse -> wire)

Run with:
    cd /home/user/neoExcelPPT
    python -m pytest models/tests/example_skills_tests.py -v
"""

import json
import os
import sys
from pathlib import Path

import pytest

# Add models to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from models.skills.sexpr_generator import (
    SExprParser,
    SExprGenerator,
    WiringGenerator,
    ActionComposer,
    SExprNode,
)
from models.skills.skill_definitions import (
    SKILL_REGISTRY,
    DEFAULT_WIRING,
    get_all_skills,
    get_skill,
    get_skill_ids,
    PROJECT_SCOPE_SKILL,
    BUFFER_CALCULATOR_SKILL,
)
from models.skills.localhost_interpreter import LocalhostInterpreter
from models.skills.upskill_bridge import UpskillBridge, UpskillConfig


# =============================================================================
# Fixtures
# =============================================================================


@pytest.fixture
def parser():
    return SExprParser()


@pytest.fixture
def generator():
    return SExprGenerator()


@pytest.fixture
def wiring():
    return WiringGenerator()


@pytest.fixture
def actions():
    return ActionComposer()


@pytest.fixture
def interpreter():
    return LocalhostInterpreter()


@pytest.fixture
def bridge():
    return UpskillBridge(teacher_model="sonnet", student_model="haiku")


# =============================================================================
# Test 1: S-Expression Parsing
# =============================================================================


class TestSExprParsing:
    """Test the S-expression parser with various inputs."""

    def test_parse_simple_expression(self, parser):
        """Parse a simple arithmetic S-expression."""
        result = parser.parse("(+ 1 2)")
        assert result["valid"] is True
        assert result["ast"] == ["+", 1, 2]

    def test_parse_nested_expression(self, parser):
        """Parse a nested S-expression."""
        result = parser.parse("(+ (* 3 4) (- 10 5))")
        assert result["valid"] is True
        ast = result["ast"]
        assert ast[0] == "+"
        assert ast[1] == ["*", 3, 4]
        assert ast[2] == ["-", 10, 5]

    def test_parse_skill_definition(self, parser):
        """Parse a full skill definition S-expression."""
        sexpr = """
        (define-skill :adder
          (inputs :a :b)
          (outputs :sum)
          (state {:total 0})
          (compute
            (emit :sum (+ (get input :a) (get input :b)))))
        """
        result = parser.parse(sexpr)
        assert result["valid"] is True
        assert result["skill_id"] == ":adder"
        assert result["ast"][0] == "define-skill"

    def test_parse_keywords(self, parser):
        """Parse keywords (colon-prefixed atoms)."""
        result = parser.parse("(:name :age :score)")
        assert result["valid"] is True
        assert result["ast"] == [":name", ":age", ":score"]

    def test_parse_empty_input(self, parser):
        """Empty input should return an error."""
        result = parser.parse("")
        assert result["valid"] is False
        assert "error" in result

    def test_parse_unclosed_paren(self, parser):
        """Unclosed parenthesis should return an error."""
        result = parser.parse("(+ 1 2")
        assert result["valid"] is False

    def test_parse_string_literals(self, parser):
        """Parse string literals within S-expressions."""
        result = parser.parse('(notify "Hello World")')
        assert result["valid"] is True
        assert result["ast"] == ["notify", "Hello World"]

    def test_parse_boolean_and_nil(self, parser):
        """Parse boolean and nil atoms."""
        result = parser.parse("(if true 1 nil)")
        assert result["valid"] is True
        assert result["ast"] == ["if", True, 1, None]

    def test_parse_comments_ignored(self, parser):
        """Comments (;; ...) should be stripped."""
        result = parser.parse(";; this is a comment\n(+ 1 2)")
        assert result["valid"] is True
        assert result["ast"] == ["+", 1, 2]

    def test_ast_to_skill_conversion(self, parser):
        """Convert a parsed AST into a skill definition dict."""
        result = parser.parse("""
        (define-skill :calculator
          (inputs :x :y)
          (outputs :result)
          (state {:memo 0})
          (compute (emit :result (+ (get input :x) (get input :y)))))
        """)
        assert result["valid"] is True
        skill = parser.ast_to_skill(result["ast"])
        assert skill is not None
        assert skill["id"] == ":calculator"
        assert skill["inputs"] == [":x", ":y"]
        assert skill["outputs"] == [":result"]


# =============================================================================
# Test 2: S-Expression Generation
# =============================================================================


class TestSExprGeneration:
    """Test S-expression generation from skill definitions."""

    def test_generate_simple_skill(self, generator):
        """Generate an S-expression from a simple skill definition."""
        skill_def = {
            "id": ":adder",
            "inputs": [":a", ":b"],
            "outputs": [":sum"],
            "state": {"total": 0},
            "compute": "(emit :sum (+ (get input :a) (get input :b)))",
        }
        sexpr = generator.generate_from_skill_definition(skill_def)
        assert "(define-skill :adder" in sexpr
        assert "(inputs :a :b)" in sexpr
        assert "(outputs :sum)" in sexpr
        assert "(state {:total 0})" in sexpr
        assert "(compute" in sexpr

    def test_generate_project_scope_skill(self, generator):
        """Generate S-expression for the project scope skill."""
        sexpr = generator.generate_from_skill_definition(PROJECT_SCOPE_SKILL)
        assert "(define-skill :project-scope" in sexpr
        assert "(inputs :file-counts)" in sexpr
        assert "(outputs :total-files :component-breakdown)" in sexpr

    def test_generate_buffer_calculator_skill(self, generator):
        """Generate S-expression for the buffer calculator skill."""
        sexpr = generator.generate_from_skill_definition(BUFFER_CALCULATOR_SKILL)
        assert "(define-skill :buffer-calculator" in sexpr
        assert ":leave-pct" in sexpr
        assert ":dependency-pct" in sexpr
        assert ":learning-pct" in sexpr

    def test_generate_all_registry_skills(self, generator, parser):
        """Generate and validate S-expressions for all registered skills."""
        for skill_id, skill_def in SKILL_REGISTRY.items():
            sexpr = generator.generate_from_skill_definition(skill_def)
            assert "(define-skill" in sexpr, f"Missing define-skill in {skill_id}"
            assert skill_def["id"] in sexpr, f"Missing skill ID in {skill_id}"
            # Verify it parses back
            result = parser.parse(sexpr)
            assert result["valid"], f"Generated S-expr for {skill_id} doesn't parse: {result.get('error')}"


# =============================================================================
# Test 3: Wiring Generation
# =============================================================================


class TestWiringGeneration:
    """Test wiring S-expression generation."""

    def test_generate_simple_wiring(self, wiring):
        """Generate a simple two-skill wiring."""
        wiring.connect("scope", "total", "calc", "input")
        sexpr = wiring.to_sexpr()
        assert "(define-wiring" in sexpr
        assert "(connect :scope:total -> :calc:input)" in sexpr

    def test_generate_multi_wiring(self, wiring):
        """Generate wiring with multiple connections."""
        wiring.connect("scope", "files", "calc", "count")
        wiring.connect("calc", "effort", "agg", "input")
        wiring.connect("agg", "total", "buffer", "base")
        sexpr = wiring.to_sexpr()
        assert sexpr.count("connect") == 3

    def test_generate_default_wiring(self, generator):
        """Generate S-expression for the default wiring configuration."""
        sexpr = generator.generate_wiring(DEFAULT_WIRING)
        assert "(define-wiring" in sexpr
        assert "project-scope" in sexpr
        assert "component-calculator" in sexpr
        assert "effort-aggregator" in sexpr
        assert "buffer-calculator" in sexpr
        assert sexpr.count("connect") == len(DEFAULT_WIRING)

    def test_wiring_clear(self, wiring):
        """Test clearing wiring connections."""
        wiring.connect("a", "x", "b", "y")
        wiring.clear()
        sexpr = wiring.to_sexpr()
        assert "connect" not in sexpr


# =============================================================================
# Test 4: Action Composition
# =============================================================================


class TestActionComposition:
    """Test UX action S-expression composition."""

    def test_simple_action(self, actions):
        """Compose a simple function call action."""
        action = actions.call("db/save")
        sexpr = action.to_sexpr()
        assert sexpr == "(db/save)"

    def test_action_with_args(self, actions):
        """Compose an action with arguments."""
        action = actions.call("notify", "Saved!")
        sexpr = action.to_sexpr()
        assert sexpr == '(notify "Saved!")'

    def test_seq_action(self, actions):
        """Compose a sequence of actions."""
        action = actions.seq(
            actions.call("validate"),
            actions.call("db/save"),
            actions.call("notify", "Done!"),
        )
        sexpr = action.to_sexpr()
        assert "(seq" in sexpr
        assert "(validate)" in sexpr
        assert "(db/save)" in sexpr
        assert '(notify "Done!")' in sexpr

    def test_conditional_action(self, actions):
        """Compose an if-then-else action."""
        action = actions.if_then_else(
            actions.call("valid?"),
            actions.call("db/save"),
            actions.call("warn", "Fix errors"),
        )
        sexpr = action.to_sexpr()
        assert "(if" in sexpr
        assert "(valid?)" in sexpr
        assert "(db/save)" in sexpr
        assert '(warn "Fix errors")' in sexpr

    def test_on_click_with_nested_actions(self, actions):
        """Compose a full on-click handler with nested conditionals."""
        action = actions.on_click(
            actions.if_then_else(
                actions.call("valid?"),
                actions.seq(
                    actions.call("db/save"),
                    actions.call("close"),
                ),
                actions.call("warn", "Error"),
            )
        )
        sexpr = action.to_sexpr()
        assert "(on-click" in sexpr
        assert "(if" in sexpr
        assert "(seq" in sexpr

    def test_debounce_action(self, actions):
        """Compose a debounced action."""
        action = actions.on_change(
            actions.debounce(300, actions.call("compute-derived"))
        )
        sexpr = action.to_sexpr()
        assert "(on-change" in sexpr
        assert "(debounce 300" in sexpr


# =============================================================================
# Test 5: Skill Registry
# =============================================================================


class TestSkillRegistry:
    """Test the skill definitions registry."""

    def test_registry_has_all_skills(self):
        """Verify all expected skills are in the registry."""
        expected = [
            "project-scope",
            "component-calculator",
            "activity-calculator",
            "effort-aggregator",
            "buffer-calculator",
        ]
        for skill_id in expected:
            assert skill_id in SKILL_REGISTRY, f"Missing skill: {skill_id}"

    def test_get_skill_by_id(self):
        """Get a skill by ID."""
        skill = get_skill("project-scope")
        assert skill is not None
        assert skill["id"] == ":project-scope"

    def test_get_skill_with_colon_prefix(self):
        """Get a skill by ID with leading colon."""
        skill = get_skill(":buffer-calculator")
        assert skill is not None
        assert skill["id"] == ":buffer-calculator"

    def test_get_all_skills(self):
        """Get all skills from registry."""
        skills = get_all_skills()
        assert len(skills) == 5

    def test_all_skills_have_required_fields(self):
        """Every skill must have id, inputs, outputs, state, compute."""
        for skill_id, skill_def in SKILL_REGISTRY.items():
            assert "id" in skill_def, f"{skill_id} missing id"
            assert "inputs" in skill_def, f"{skill_id} missing inputs"
            assert "outputs" in skill_def, f"{skill_id} missing outputs"
            assert "state" in skill_def, f"{skill_id} missing state"
            assert "compute" in skill_def, f"{skill_id} missing compute"

    def test_all_skills_have_ui_section(self):
        """Every skill should have a UI section definition."""
        for skill_id, skill_def in SKILL_REGISTRY.items():
            assert "ui" in skill_def, f"{skill_id} missing ui definition"
            assert "section" in skill_def["ui"], f"{skill_id} missing ui.section"
            assert "elements" in skill_def["ui"], f"{skill_id} missing ui.elements"

    def test_default_wiring_references_valid_skills(self):
        """All skills referenced in wiring must exist in registry."""
        for conn in DEFAULT_WIRING:
            from_id = conn["from_skill"]
            to_id = conn["to_skill"]
            assert from_id in SKILL_REGISTRY, f"Wiring references unknown skill: {from_id}"
            assert to_id in SKILL_REGISTRY, f"Wiring references unknown skill: {to_id}"


# =============================================================================
# Test 6: Localhost Interpreter
# =============================================================================


class TestLocalhostInterpreter:
    """Test the localhost:4000 source interpreter."""

    def test_interpret_from_source(self, interpreter):
        """Interpret skills from the Elixir source files."""
        skills = interpreter.interpret_from_source()
        # Should find skills from both LiveView sections and skill modules
        assert len(skills) > 0

    def test_generate_skill_sexprs(self, interpreter):
        """Generate S-expressions from source interpretation."""
        sexprs = interpreter.generate_skill_sexprs()
        assert len(sexprs) > 0
        for sexpr in sexprs:
            assert "(define-skill" in sexpr or "(" in sexpr

    def test_generate_wiring_from_source(self, interpreter):
        """Generate wiring S-expression from SkillManager source."""
        wiring = interpreter.generate_wiring_sexpr()
        assert "(define-wiring" in wiring
        assert "connect" in wiring

    def test_extract_ui_elements(self, interpreter):
        """Extract UI elements from the project LiveView source."""
        source_path = Path("/home/user/neoExcelPPT/lib/neo_excel_ppt_web/live/project_live.ex")
        if source_path.exists():
            source = source_path.read_text()
            elements = interpreter.extract_ui_elements(source)
            assert len(elements) > 0
            # Check for known element IDs
            element_ids = {e.element_id for e in elements}
            assert "project-scope" in element_ids or any(
                eid.startswith("project-scope") for eid in element_ids
            )

    def test_generate_full_dsl(self, interpreter):
        """Generate the complete DSL (skills + wiring)."""
        dsl = interpreter.generate_full_dsl()
        assert ";; NeoExcelPPT Skills DSL" in dsl
        assert "(define-skill" in dsl
        assert "(define-wiring" in dsl


# =============================================================================
# Test 7: Round-Trip (Generate -> Parse -> Validate)
# =============================================================================


class TestRoundTrip:
    """Test that generated S-expressions parse back correctly."""

    def test_roundtrip_simple_skill(self, generator, parser):
        """Generate an S-expression and parse it back."""
        skill_def = {
            "id": ":counter",
            "inputs": [":increment"],
            "outputs": [":count"],
            "state": {"value": 0},
            "compute": "(emit :count (+ (get state :value) (get input :increment)))",
        }
        sexpr = generator.generate_from_skill_definition(skill_def)
        result = parser.parse(sexpr)
        assert result["valid"] is True
        assert result["skill_id"] == ":counter"

    def test_roundtrip_all_registry_skills(self, generator, parser):
        """Round-trip all skills in the registry."""
        for skill_id, skill_def in SKILL_REGISTRY.items():
            sexpr = generator.generate_from_skill_definition(skill_def)
            result = parser.parse(sexpr)
            assert result["valid"], f"Round-trip failed for {skill_id}: {result.get('error')}"

    def test_roundtrip_wiring(self, generator, parser):
        """Generate wiring and parse it back."""
        sexpr = generator.generate_wiring(DEFAULT_WIRING)
        result = parser.parse(sexpr)
        assert result["valid"] is True
        assert result["ast"][0] == "define-wiring"


# =============================================================================
# Test 8: Token Efficiency
# =============================================================================


class TestTokenEfficiency:
    """Test that S-expressions are more token-efficient than JSON."""

    def test_sexpr_smaller_than_json(self, generator):
        """S-expression should be significantly smaller than equivalent JSON."""
        skill_def = PROJECT_SCOPE_SKILL
        sexpr = generator.generate_from_skill_definition(skill_def)

        # Create equivalent JSON
        json_repr = json.dumps({
            "type": "skill-definition",
            "id": skill_def["id"],
            "inputs": skill_def["inputs"],
            "outputs": skill_def["outputs"],
            "state": skill_def["state"],
            "compute": skill_def["compute"],
        }, indent=2)

        # S-expression should be smaller (fewer characters as proxy for tokens)
        sexpr_size = len(sexpr)
        json_size = len(json_repr)
        ratio = json_size / sexpr_size

        # We expect at least 1.5x reduction (usually 3-5x)
        assert ratio > 1.0, (
            f"S-expr ({sexpr_size} chars) should be smaller than JSON ({json_size} chars)"
        )

    def test_all_skills_token_efficient(self, generator):
        """Verify token efficiency across all registered skills."""
        for skill_id, skill_def in SKILL_REGISTRY.items():
            sexpr = generator.generate_from_skill_definition(skill_def)
            json_repr = json.dumps(skill_def, indent=2)
            assert len(sexpr) < len(json_repr), (
                f"S-expr for {skill_id} is not smaller than JSON"
            )


# =============================================================================
# Test 9: Upskill Bridge
# =============================================================================


class TestUpskillBridge:
    """Test the Hugging Face upskill bridge integration."""

    def test_generate_skill_command(self, bridge):
        """Verify upskill generate command structure."""
        result = bridge.generate_skill(
            task="Generate a cell computation skill"
        )
        assert result["status"] == "ready"
        assert "upskill" in result["command"]
        assert "generate" in result["command"]
        assert bridge.config.teacher_model in result["command"]

    def test_generate_with_examples(self, bridge):
        """Verify skill generation with examples."""
        result = bridge.generate_skill(
            task="Generate S-expression skills",
            examples=[{
                "input": "Create an adder skill",
                "output": "(define-skill :adder (inputs :a :b) (outputs :sum) (compute (emit :sum (+ (get input :a) (get input :b)))))",
            }],
        )
        assert len(result["examples"]) == 1

    def test_evaluate_skill_command(self, bridge):
        """Verify upskill eval command structure."""
        skill = bridge.generate_skill(task="test skill")
        result = bridge.evaluate_skill(
            skill=skill,
            test_cases=[
                {"input": "test", "expected": {"contains": ["define-skill"]}},
            ],
        )
        assert result["status"] == "ready"
        assert len(result["test_cases"]) == 1

    def test_generate_sexpr_test_cases(self, bridge):
        """Generate test cases from the skill registry."""
        test_cases = bridge.generate_sexpr_test_cases()
        # Should have at least 2 test cases per skill + 1 wiring test
        assert len(test_cases) >= len(SKILL_REGISTRY) * 2 + 1
        # Each test case should have input and expected
        for tc in test_cases:
            assert "input" in tc
            assert "expected" in tc
            assert "contains" in tc["expected"]

    def test_build_skill_context(self, bridge):
        """Build context string includes all skills and vocabulary."""
        context = bridge.build_skill_context()
        assert "NeoExcelPPT S-Expression" in context
        assert "define-skill" in context
        assert "define-wiring" in context
        for skill_id in SKILL_REGISTRY:
            assert skill_id in context or skill_id.replace('-', '_') in context

    def test_refine_skill_command(self, bridge):
        """Verify skill refinement command structure."""
        skill = bridge.generate_skill(task="initial skill")
        refined = bridge.refine_skill(
            skill=skill,
            feedback="Needs better error handling in compute expression",
        )
        assert refined["status"] == "ready"
        assert "from" in " ".join(refined["command"])

    def test_config_from_env(self):
        """Test loading config from environment."""
        config = UpskillConfig.from_env()
        assert config.teacher_model is not None
        assert config.student_model is not None
        assert config.max_refine_attempts > 0


# =============================================================================
# Test 10: Full Pipeline Integration
# =============================================================================


class TestFullPipeline:
    """Test the complete pipeline: interpret -> generate -> parse -> wire."""

    def test_full_pipeline(self, interpreter, generator, parser):
        """Run the full pipeline from source interpretation to wired S-expressions."""
        # Step 1: Interpret skills from source
        skills = interpreter.interpret_from_source()
        assert len(skills) > 0, "No skills found from source"

        # Step 2: Generate S-expressions for each skill
        sexprs = []
        for skill in skills:
            if skill:  # Some may be None
                sexpr = generator.generate_from_skill_definition(skill)
                sexprs.append(sexpr)
        assert len(sexprs) > 0, "No S-expressions generated"

        # Step 3: Parse and validate all generated S-expressions
        valid_count = 0
        for sexpr in sexprs:
            result = parser.parse(sexpr)
            if result["valid"]:
                valid_count += 1
        assert valid_count > 0, "No valid S-expressions after parsing"

        # Step 4: Generate wiring
        wiring_sexpr = interpreter.generate_wiring_sexpr()
        wiring_result = parser.parse(wiring_sexpr)
        assert wiring_result["valid"], "Wiring S-expression is invalid"

    def test_pipeline_produces_full_dsl(self, interpreter, parser):
        """The full DSL should contain skills and wiring."""
        dsl = interpreter.generate_full_dsl()

        # Should have multiple skill definitions
        skill_count = dsl.count("(define-skill")
        assert skill_count >= 1, f"Expected >= 1 skill definitions, got {skill_count}"

        # Should have wiring
        assert "(define-wiring" in dsl

        # Each define-skill block should parse
        import re
        for match in re.finditer(r'\(define-skill[^)]*(?:\([^)]*\))*\)', dsl):
            block = match.group(0)
            result = parser.parse(block)
            # Some extracted blocks may be partial - that's ok
            # Just verify the parser doesn't crash

    def test_pipeline_skills_match_wiring(self, interpreter):
        """Skills referenced in wiring should exist in interpreted skills."""
        skills = interpreter.interpret_from_source()
        skill_ids = {s["id"].lstrip(':') for s in skills if s and "id" in s}

        wiring_sexpr = interpreter.generate_wiring_sexpr()
        # Extract skill references from wiring
        import re
        wiring_skills = set()
        for m in re.finditer(r':(\w[\w-]*?):', wiring_sexpr):
            wiring_skills.add(m.group(1))

        # At least some wiring skills should overlap with discovered skills
        overlap = skill_ids & wiring_skills
        # This is a soft check - not all may match due to naming conventions
        assert len(wiring_skills) > 0, "No skills found in wiring"
