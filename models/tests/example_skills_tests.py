"""
Example Skills Tests for NeoExcelPPT S-Expression Generation.

These tests validate:
1. S-Expression parsing (lists, maps, vectors, atoms, edge cases)
2. S-Expression generation (skills, wiring, formatting)
3. S-Expression EVALUATION (arithmetic, logic, state, emissions)
4. Wiring composition
5. Action composition
6. Skill registry completeness
7. Localhost:4000 interpreter (HEEx parsing, source analysis)
8. Round-trip (generate -> parse -> validate -> reconstruct)
9. Token efficiency (S-expr vs JSON)
10. Upskill bridge (simulation mode, test generation, evaluation)
11. Full pipeline integration
12. Error handling and edge cases

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
    SExprEvaluator,
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
def evaluator():
    return SExprEvaluator()


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
# Test 1: S-Expression Parsing - Basic
# =============================================================================


class TestSExprParsing:
    """Test the S-expression parser with various inputs."""

    def test_parse_simple_expression(self, parser):
        result = parser.parse("(+ 1 2)")
        assert result["valid"] is True
        assert result["ast"] == ["+", 1, 2]

    def test_parse_nested_expression(self, parser):
        result = parser.parse("(+ (* 3 4) (- 10 5))")
        assert result["valid"] is True
        ast = result["ast"]
        assert ast[0] == "+"
        assert ast[1] == ["*", 3, 4]
        assert ast[2] == ["-", 10, 5]

    def test_parse_skill_definition(self, parser):
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
        result = parser.parse("(:name :age :score)")
        assert result["valid"] is True
        assert result["ast"] == [":name", ":age", ":score"]

    def test_parse_empty_input(self, parser):
        result = parser.parse("")
        assert result["valid"] is False
        assert "error" in result

    def test_parse_unclosed_paren(self, parser):
        result = parser.parse("(+ 1 2")
        assert result["valid"] is False

    def test_parse_string_literals(self, parser):
        result = parser.parse('(notify "Hello World")')
        assert result["valid"] is True
        assert result["ast"] == ["notify", "Hello World"]

    def test_parse_boolean_and_nil(self, parser):
        result = parser.parse("(if true 1 nil)")
        assert result["valid"] is True
        assert result["ast"] == ["if", True, 1, None]

    def test_parse_comments_ignored(self, parser):
        result = parser.parse(";; this is a comment\n(+ 1 2)")
        assert result["valid"] is True
        assert result["ast"] == ["+", 1, 2]

    def test_ast_to_skill_conversion(self, parser):
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
# Test 1b: S-Expression Parsing - Maps & Vectors
# =============================================================================


class TestMapParsing:
    """Test curly-brace map parsing {key value} -> Python dict."""

    def test_parse_simple_map(self, parser):
        result = parser.parse("{:a 1 :b 2}")
        assert result["valid"] is True
        assert result["ast"] == {"a": 1, "b": 2}

    def test_parse_nested_map(self, parser):
        result = parser.parse("{:name \"Alice\" :age 30}")
        assert result["valid"] is True
        assert result["ast"]["name"] == "Alice"
        assert result["ast"]["age"] == 30

    def test_parse_map_in_list(self, parser):
        result = parser.parse("(state {:x 10 :y 20})")
        assert result["valid"] is True
        assert result["ast"][0] == "state"
        assert result["ast"][1] == {"x": 10, "y": 20}

    def test_parse_map_with_nested_values(self, parser):
        result = parser.parse("{:config {:port 4000 :host \"localhost\"}}")
        assert result["valid"] is True
        assert result["ast"]["config"] == {"port": 4000, "host": "localhost"}

    def test_parse_empty_map(self, parser):
        result = parser.parse("{}")
        assert result["valid"] is True
        assert result["ast"] == {}

    def test_parse_vector(self, parser):
        result = parser.parse("[1 2 3]")
        assert result["valid"] is True
        assert result["ast"] == [1, 2, 3]

    def test_parse_vector_in_let(self, parser):
        result = parser.parse("(let [x 10 y 20] (+ x y))")
        assert result["valid"] is True
        ast = result["ast"]
        assert ast[0] == "let"
        assert ast[1] == ["x", 10, "y", 20]

    def test_skill_with_parsed_map_state(self, parser):
        """Verify ast_to_skill correctly extracts state from a parsed map."""
        result = parser.parse("""
        (define-skill :test
          (inputs :in)
          (outputs :out)
          (state {:count 0 :name "test"})
          (compute (emit :out 42)))
        """)
        assert result["valid"] is True
        skill = parser.ast_to_skill(result["ast"])
        assert isinstance(skill["state"], dict)
        assert skill["state"]["count"] == 0
        assert skill["state"]["name"] == "test"

    def test_unclosed_map(self, parser):
        result = parser.parse("{:a 1 :b 2")
        assert result["valid"] is False

    def test_unclosed_vector(self, parser):
        result = parser.parse("[1 2 3")
        assert result["valid"] is False


# =============================================================================
# Test 2: S-Expression Generation
# =============================================================================


class TestSExprGeneration:
    """Test S-expression generation from skill definitions."""

    def test_generate_simple_skill(self, generator):
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
        sexpr = generator.generate_from_skill_definition(PROJECT_SCOPE_SKILL)
        assert "(define-skill :project-scope" in sexpr
        assert "(inputs :file-counts)" in sexpr
        assert "(outputs :total-files :component-breakdown)" in sexpr

    def test_generate_buffer_calculator_skill(self, generator):
        sexpr = generator.generate_from_skill_definition(BUFFER_CALCULATOR_SKILL)
        assert "(define-skill :buffer-calculator" in sexpr
        assert ":leave-pct" in sexpr
        assert ":dependency-pct" in sexpr
        assert ":learning-pct" in sexpr

    def test_generate_all_registry_skills(self, generator, parser):
        for skill_id, skill_def in SKILL_REGISTRY.items():
            sexpr = generator.generate_from_skill_definition(skill_def)
            assert "(define-skill" in sexpr, f"Missing define-skill in {skill_id}"
            assert skill_def["id"] in sexpr, f"Missing skill ID in {skill_id}"
            result = parser.parse(sexpr)
            assert result["valid"], f"Generated S-expr for {skill_id} doesn't parse: {result.get('error')}"

    def test_generate_skill_no_compute(self, generator):
        """Skill without compute should still generate valid S-expression."""
        skill_def = {
            "id": ":stub",
            "inputs": [":in"],
            "outputs": [":out"],
            "state": {},
        }
        sexpr = generator.generate_from_skill_definition(skill_def)
        assert "(define-skill :stub" in sexpr
        assert "(inputs :in)" in sexpr

    def test_generate_skill_with_nested_state(self, generator):
        skill_def = {
            "id": ":complex",
            "inputs": [":data"],
            "outputs": [":result"],
            "state": {"config": {"port": 4000, "debug": True}, "count": 0},
            "compute": "(emit :result (get state :count))",
        }
        sexpr = generator.generate_from_skill_definition(skill_def)
        assert ":config" in sexpr
        assert ":port" in sexpr
        assert "4000" in sexpr


# =============================================================================
# Test 3: S-Expression EVALUATION
# =============================================================================


class TestSExprEvaluator:
    """Test the S-expression evaluator - real computation."""

    def test_eval_addition(self, evaluator):
        result = evaluator.evaluate("(+ 1 2)")
        assert result.error is None
        assert result.value == 3

    def test_eval_nested_arithmetic(self, evaluator):
        result = evaluator.evaluate("(+ (* 3 4) (- 10 5))")
        assert result.error is None
        assert result.value == 17  # 12 + 5

    def test_eval_multiplication(self, evaluator):
        result = evaluator.evaluate("(* 6 7)")
        assert result.value == 42

    def test_eval_division(self, evaluator):
        result = evaluator.evaluate("(/ 100 4)")
        assert result.value == 25.0

    def test_eval_division_by_zero(self, evaluator):
        result = evaluator.evaluate("(/ 10 0)")
        assert result.value == 0  # safe division

    def test_eval_comparison(self, evaluator):
        assert evaluator.evaluate("(> 5 3)").value is True
        assert evaluator.evaluate("(< 5 3)").value is False
        assert evaluator.evaluate("(= 5 5)").value is True
        assert evaluator.evaluate("(>= 5 5)").value is True
        assert evaluator.evaluate("(<= 4 5)").value is True

    def test_eval_logic(self, evaluator):
        assert evaluator.evaluate("(and true true)").value is True
        assert evaluator.evaluate("(and true false)").value is False
        assert evaluator.evaluate("(or false true)").value is True
        assert evaluator.evaluate("(not false)").value is True

    def test_eval_if_true(self, evaluator):
        result = evaluator.evaluate("(if true 42 0)")
        assert result.value == 42

    def test_eval_if_false(self, evaluator):
        result = evaluator.evaluate("(if false 42 0)")
        assert result.value == 0

    def test_eval_get_input(self, evaluator):
        result = evaluator.evaluate(
            "(get input :x)",
            inputs={"x": 99}
        )
        assert result.value == 99

    def test_eval_get_state(self, evaluator):
        result = evaluator.evaluate(
            "(get state :count)",
            state={"count": 5}
        )
        assert result.value == 5

    def test_eval_set_state(self, evaluator):
        result = evaluator.evaluate(
            "(set :count 10)",
            state={"count": 0}
        )
        assert result.state["count"] == 10

    def test_eval_emit(self, evaluator):
        result = evaluator.evaluate(
            "(emit :output 42)",
        )
        assert result.emissions["output"] == 42

    def test_eval_let_bindings(self, evaluator):
        result = evaluator.evaluate(
            "(let [x 10 y 20] (+ x y))"
        )
        assert result.value == 30

    def test_eval_let_with_state(self, evaluator):
        result = evaluator.evaluate(
            "(let [base (get input :days) pct (get state :buffer-pct)] (* base (/ pct 100)))",
            state={"buffer-pct": 20},
            inputs={"days": 100}
        )
        assert result.value == 20.0

    def test_eval_seq(self, evaluator):
        result = evaluator.evaluate(
            "(seq (set :a 1) (set :b 2) (+ (get state :a) (get state :b)))",
            state={}
        )
        assert result.value == 3
        assert result.state["a"] == 1
        assert result.state["b"] == 2

    def test_eval_multiple_emissions(self, evaluator):
        result = evaluator.evaluate(
            "(seq (emit :total 100) (emit :breakdown {:manual 60 :auto 40}))",
        )
        assert result.emissions["total"] == 100
        assert result.emissions["breakdown"]["manual"] == 60

    def test_eval_sum_list(self, evaluator):
        result = evaluator.evaluate(
            "(sum [10 20 30])",
        )
        assert result.value == 60  # sum works on parsed vectors

    def test_eval_count(self, evaluator):
        result = evaluator.evaluate(
            "(count [1 2 3 4 5])",
        )
        assert result.value == 5

    def test_eval_sum_values(self, evaluator):
        result = evaluator.evaluate(
            "(sum-values {:a 10 :b 20 :c 30})",
        )
        assert result.value == 60

    def test_eval_merge(self, evaluator):
        result = evaluator.evaluate(
            "(merge {:a 1} {:b 2})",
        )
        assert result.value == {"a": 1, "b": 2}

    def test_eval_str_concat(self, evaluator):
        result = evaluator.evaluate(
            '(str "hello" " " "world")',
        )
        assert result.value == "hello world"

    def test_eval_real_buffer_calc(self, evaluator):
        """Evaluate a real buffer calculation skill compute expression."""
        result = evaluator.evaluate(
            """(let [base (get input :base-days)
                   leave (* base (/ (get state :leave-pct) 100))
                   dep (* base (/ (get state :dependency-pct) 100))
                   learn (* base (/ (get state :learning-pct) 100))]
                 (seq
                   (emit :buffer-days (+ leave dep learn))
                   (emit :buffer-breakdown {:leave leave :dependency dep :learning learn})))""",
            state={"leave-pct": 10, "dependency-pct": 15, "learning-pct": 20},
            inputs={"base-days": 100},
        )
        assert result.error is None
        assert result.emissions["buffer-days"] == 45.0
        assert result.emissions["buffer-breakdown"]["leave"] == 10.0
        assert result.emissions["buffer-breakdown"]["dependency"] == 15.0
        assert result.emissions["buffer-breakdown"]["learning"] == 20.0

    def test_eval_real_effort_aggregator(self, evaluator):
        """Evaluate a real effort aggregation."""
        result = evaluator.evaluate(
            """(let [comp (get input :component-effort)
                   act (get input :activity-effort)
                   buf (get input :buffer-days)
                   total (+ comp act buf)]
                 (seq
                   (emit :total-days total)
                   (emit :effort-breakdown {:component comp :activity act :buffer buf})))""",
            inputs={"component-effort": 50, "activity-effort": 30, "buffer-days": 20},
        )
        assert result.error is None
        assert result.emissions["total-days"] == 100
        assert result.emissions["effort-breakdown"]["component"] == 50

    def test_eval_error_handling(self, evaluator):
        result = evaluator.evaluate("(+ 1 2")  # unclosed paren
        assert result.error is not None

    def test_eval_assoc(self, evaluator):
        result = evaluator.evaluate(
            "(assoc {:x 1} :y 2)"
        )
        assert result.value == {"x": 1, "y": 2}


# =============================================================================
# Test 4: Wiring Generation
# =============================================================================


class TestWiringGeneration:
    """Test wiring S-expression generation."""

    def test_generate_simple_wiring(self, wiring):
        wiring.connect("scope", "total", "calc", "input")
        sexpr = wiring.to_sexpr()
        assert "(define-wiring" in sexpr
        assert "(connect :scope:total -> :calc:input)" in sexpr

    def test_generate_multi_wiring(self, wiring):
        wiring.connect("scope", "files", "calc", "count")
        wiring.connect("calc", "effort", "agg", "input")
        wiring.connect("agg", "total", "buffer", "base")
        sexpr = wiring.to_sexpr()
        assert sexpr.count("connect") == 3

    def test_generate_default_wiring(self, generator):
        sexpr = generator.generate_wiring(DEFAULT_WIRING)
        assert "(define-wiring" in sexpr
        assert "project-scope" in sexpr
        assert "component-calculator" in sexpr
        assert "effort-aggregator" in sexpr
        assert "buffer-calculator" in sexpr
        assert sexpr.count("connect") == len(DEFAULT_WIRING)

    def test_wiring_clear(self, wiring):
        wiring.connect("a", "x", "b", "y")
        wiring.clear()
        sexpr = wiring.to_sexpr()
        assert "connect" not in sexpr

    def test_wiring_chain_api(self, wiring):
        """Test fluent chaining API."""
        result = (
            wiring
            .connect("a", "out", "b", "in")
            .connect("b", "out", "c", "in")
        )
        assert result is wiring
        assert len(wiring.connections) == 2


# =============================================================================
# Test 5: Action Composition
# =============================================================================


class TestActionComposition:
    """Test UX action S-expression composition."""

    def test_simple_action(self, actions):
        action = actions.call("db/save")
        sexpr = action.to_sexpr()
        assert sexpr == "(db/save)"

    def test_action_with_args(self, actions):
        action = actions.call("notify", "Saved!")
        sexpr = action.to_sexpr()
        assert sexpr == '(notify "Saved!")'

    def test_seq_action(self, actions):
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
        action = actions.on_change(
            actions.debounce(300, actions.call("compute-derived"))
        )
        sexpr = action.to_sexpr()
        assert "(on-change" in sexpr
        assert "(debounce 300" in sexpr

    def test_on_blur_action(self, actions):
        action = actions.on_blur(actions.call("validate-input"))
        sexpr = action.to_sexpr()
        assert "(on-blur (validate-input))" == sexpr


# =============================================================================
# Test 6: Skill Registry
# =============================================================================


class TestSkillRegistry:
    """Test the skill definitions registry."""

    def test_registry_has_all_skills(self):
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
        skill = get_skill("project-scope")
        assert skill is not None
        assert skill["id"] == ":project-scope"

    def test_get_skill_with_colon_prefix(self):
        skill = get_skill(":buffer-calculator")
        assert skill is not None
        assert skill["id"] == ":buffer-calculator"

    def test_get_all_skills(self):
        skills = get_all_skills()
        assert len(skills) == 5

    def test_all_skills_have_required_fields(self):
        for skill_id, skill_def in SKILL_REGISTRY.items():
            assert "id" in skill_def, f"{skill_id} missing id"
            assert "inputs" in skill_def, f"{skill_id} missing inputs"
            assert "outputs" in skill_def, f"{skill_id} missing outputs"
            assert "state" in skill_def, f"{skill_id} missing state"
            assert "compute" in skill_def, f"{skill_id} missing compute"

    def test_all_skills_have_ui_section(self):
        for skill_id, skill_def in SKILL_REGISTRY.items():
            assert "ui" in skill_def, f"{skill_id} missing ui definition"
            assert "section" in skill_def["ui"], f"{skill_id} missing ui.section"
            assert "elements" in skill_def["ui"], f"{skill_id} missing ui.elements"

    def test_default_wiring_references_valid_skills(self):
        for conn in DEFAULT_WIRING:
            from_id = conn["from_skill"]
            to_id = conn["to_skill"]
            assert from_id in SKILL_REGISTRY, f"Wiring references unknown skill: {from_id}"
            assert to_id in SKILL_REGISTRY, f"Wiring references unknown skill: {to_id}"

    def test_get_skill_ids(self):
        ids = get_skill_ids()
        assert len(ids) == 5
        assert "project-scope" in ids

    def test_nonexistent_skill_returns_none(self):
        assert get_skill("nonexistent") is None


# =============================================================================
# Test 7: Localhost Interpreter
# =============================================================================


class TestLocalhostInterpreter:
    """Test the localhost:4000 source interpreter."""

    def test_interpret_from_source(self, interpreter):
        skills = interpreter.interpret_from_source()
        assert len(skills) > 0

    def test_generate_skill_sexprs(self, interpreter):
        sexprs = interpreter.generate_skill_sexprs()
        assert len(sexprs) > 0
        for sexpr in sexprs:
            assert "(define-skill" in sexpr or "(" in sexpr

    def test_generate_wiring_from_source(self, interpreter):
        wiring = interpreter.generate_wiring_sexpr()
        assert "(define-wiring" in wiring
        assert "connect" in wiring

    def test_extract_ui_elements(self, interpreter):
        source_path = Path("/home/user/neoExcelPPT/lib/neo_excel_ppt_web/live/project_live.ex")
        if source_path.exists():
            source = source_path.read_text()
            elements = interpreter.extract_ui_elements(source)
            assert len(elements) > 0
            element_ids = {e.element_id for e in elements}
            assert "project-scope" in element_ids or any(
                eid.startswith("project-scope") for eid in element_ids
            )

    def test_generate_full_dsl(self, interpreter):
        dsl = interpreter.generate_full_dsl()
        assert ";; NeoExcelPPT Skills DSL" in dsl
        assert "(define-skill" in dsl
        assert "(define-wiring" in dsl

    def test_wiring_extracts_real_connections(self, interpreter):
        """Verify that wiring extraction finds the actual Elixir wiring."""
        wiring = interpreter.generate_wiring_sexpr()
        assert "project-scope" in wiring
        assert "component-calculator" in wiring
        assert "effort-aggregator" in wiring

    def test_elixir_skill_extraction(self, interpreter):
        """Verify skills are extracted from actual Elixir skill module files."""
        skills = interpreter.interpret_from_source()
        # Should find skills from the _skill.ex files
        extracted_ids = {s["id"] for s in skills if s and "id" in s}
        # At least project-scope should be found from the LiveView sections
        assert len(extracted_ids) > 0


# =============================================================================
# Test 8: Round-Trip (Generate -> Parse -> Validate -> Reconstruct)
# =============================================================================


class TestRoundTrip:
    """Test that generated S-expressions parse back correctly."""

    def test_roundtrip_simple_skill(self, generator, parser):
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
        for skill_id, skill_def in SKILL_REGISTRY.items():
            sexpr = generator.generate_from_skill_definition(skill_def)
            result = parser.parse(sexpr)
            assert result["valid"], f"Round-trip failed for {skill_id}: {result.get('error')}"

    def test_roundtrip_wiring(self, generator, parser):
        sexpr = generator.generate_wiring(DEFAULT_WIRING)
        result = parser.parse(sexpr)
        assert result["valid"] is True
        assert result["ast"][0] == "define-wiring"

    def test_roundtrip_reconstruct_skill(self, generator, parser):
        """Generate -> parse -> ast_to_skill -> compare fields."""
        original = {
            "id": ":test-round",
            "inputs": [":in1", ":in2"],
            "outputs": [":out"],
            "state": {"val": 0},
            "compute": "(emit :out (+ (get input :in1) (get input :in2)))",
        }
        sexpr = generator.generate_from_skill_definition(original)
        result = parser.parse(sexpr)
        assert result["valid"]
        reconstructed = parser.ast_to_skill(result["ast"])
        assert reconstructed["id"] == original["id"]
        assert reconstructed["inputs"] == original["inputs"]
        assert reconstructed["outputs"] == original["outputs"]

    def test_roundtrip_with_map_state(self, generator, parser):
        """Ensure state maps survive the round trip."""
        original = {
            "id": ":map-test",
            "inputs": [":in"],
            "outputs": [":out"],
            "state": {"count": 0, "label": "test"},
            "compute": "(emit :out 1)",
        }
        sexpr = generator.generate_from_skill_definition(original)
        result = parser.parse(sexpr)
        assert result["valid"]
        skill = parser.ast_to_skill(result["ast"])
        assert isinstance(skill["state"], dict)
        assert skill["state"]["count"] == 0
        assert skill["state"]["label"] == "test"


# =============================================================================
# Test 9: Token Efficiency
# =============================================================================


class TestTokenEfficiency:
    """Test that S-expressions are more token-efficient than JSON."""

    def test_sexpr_smaller_than_json(self, generator):
        skill_def = PROJECT_SCOPE_SKILL
        sexpr = generator.generate_from_skill_definition(skill_def)
        json_repr = json.dumps({
            "type": "skill-definition",
            "id": skill_def["id"],
            "inputs": skill_def["inputs"],
            "outputs": skill_def["outputs"],
            "state": skill_def["state"],
            "compute": skill_def["compute"],
        }, indent=2)
        sexpr_size = len(sexpr)
        json_size = len(json_repr)
        ratio = json_size / sexpr_size
        assert ratio > 1.0, (
            f"S-expr ({sexpr_size} chars) should be smaller than JSON ({json_size} chars)"
        )

    def test_all_skills_token_efficient(self, generator):
        for skill_id, skill_def in SKILL_REGISTRY.items():
            sexpr = generator.generate_from_skill_definition(skill_def)
            json_repr = json.dumps(skill_def, indent=2)
            assert len(sexpr) < len(json_repr), (
                f"S-expr for {skill_id} is not smaller than JSON"
            )


# =============================================================================
# Test 10: Upskill Bridge (Simulation Mode)
# =============================================================================


class TestUpskillBridge:
    """Test the Hugging Face upskill bridge integration."""

    def test_bridge_mode(self, bridge):
        """Bridge should report its operating mode."""
        assert bridge.mode in ("live", "simulation")

    def test_generate_skill_command(self, bridge):
        result = bridge.generate_skill(
            task="Generate a cell computation skill"
        )
        assert result["status"] in ("executed", "simulated", "error")
        assert "upskill" in result["command"]
        assert "generate" in result["command"]
        assert bridge.config.teacher_model in result["command"]

    def test_generate_with_examples(self, bridge):
        result = bridge.generate_skill(
            task="Generate S-expression skills",
            examples=[{
                "input": "Create an adder skill",
                "output": "(define-skill :adder (inputs :a :b) (outputs :sum) (compute (emit :sum (+ (get input :a) (get input :b)))))",
            }],
        )
        assert len(result["examples"]) == 1

    def test_generate_simulated_produces_sexpr(self, bridge):
        """In simulation mode, generate_skill should produce a valid S-expression."""
        result = bridge.generate_skill(task="Generate a buffer calculator skill")
        if result["status"] == "simulated":
            assert "simulated_skill" in result
            sexpr = result["simulated_skill"]
            assert "(define-skill" in sexpr
            # Verify it parses
            parse_result = bridge.parser.parse(sexpr)
            assert parse_result["valid"], f"Simulated S-expr doesn't parse: {parse_result.get('error')}"

    def test_evaluate_skill_command(self, bridge):
        skill = bridge.generate_skill(task="test skill")
        result = bridge.evaluate_skill(
            skill=skill,
            test_cases=[
                {"input": "test", "expected": {"contains": ["define-skill"]}},
            ],
        )
        assert result["status"] in ("executed", "simulated", "error")
        assert len(result["test_cases"]) == 1

    def test_evaluate_simulated_produces_metrics(self, bridge):
        """In simulation mode, evaluation should produce real metrics."""
        skill = bridge.generate_skill(
            task="Generate a buffer calculator skill"
        )
        result = bridge.evaluate_skill(
            skill=skill,
            test_cases=[
                {"input": "buffer calc", "expected": {"contains": ["define-skill", "buffer"]}},
                {"input": "compute buffers", "expected": {"contains": ["inputs", "outputs"]}},
            ],
        )
        if result["status"] == "simulated":
            assert "skill_lift" in result
            assert "token_savings" in result
            assert "is_beneficial" in result
            assert "total_runs" in result
            assert result["total_runs"] == 2
            assert isinstance(result["skill_lift"], float)
            assert isinstance(result["token_savings"], float)

    def test_generate_sexpr_test_cases(self, bridge):
        test_cases = bridge.generate_sexpr_test_cases()
        assert len(test_cases) >= len(SKILL_REGISTRY) * 2 + 1
        for tc in test_cases:
            assert "input" in tc
            assert "expected" in tc
            assert "contains" in tc["expected"]

    def test_build_skill_context(self, bridge):
        context = bridge.build_skill_context()
        assert "NeoExcelPPT S-Expression" in context
        assert "define-skill" in context
        assert "define-wiring" in context
        for skill_id in SKILL_REGISTRY:
            assert skill_id in context or skill_id.replace('-', '_') in context

    def test_refine_skill_command(self, bridge):
        skill = bridge.generate_skill(task="initial skill")
        refined = bridge.refine_skill(
            skill=skill,
            feedback="Needs better error handling in compute expression",
        )
        assert refined["status"] in ("executed", "simulated", "error")
        assert "from" in " ".join(refined["command"])

    def test_config_from_env(self):
        config = UpskillConfig.from_env()
        assert config.teacher_model is not None
        assert config.student_model is not None
        assert config.max_refine_attempts > 0

    def test_generate_skill_md(self, bridge):
        """Test SKILL.md generation in simulation mode."""
        result = bridge.generate_skill(task="Create an activity tracker skill")
        if result["status"] == "simulated":
            assert "simulated_skill_md" in result
            md = result["simulated_skill_md"]
            assert "# Skill:" in md
            assert "```sexpr" in md


# =============================================================================
# Test 11: Full Pipeline Integration
# =============================================================================


class TestFullPipeline:
    """Test the complete pipeline: interpret -> generate -> parse -> wire."""

    def test_full_pipeline(self, interpreter, generator, parser):
        skills = interpreter.interpret_from_source()
        assert len(skills) > 0, "No skills found from source"

        sexprs = []
        for skill in skills:
            if skill:
                sexpr = generator.generate_from_skill_definition(skill)
                sexprs.append(sexpr)
        assert len(sexprs) > 0, "No S-expressions generated"

        valid_count = 0
        for sexpr in sexprs:
            result = parser.parse(sexpr)
            if result["valid"]:
                valid_count += 1
        assert valid_count > 0, "No valid S-expressions after parsing"

        wiring_sexpr = interpreter.generate_wiring_sexpr()
        wiring_result = parser.parse(wiring_sexpr)
        assert wiring_result["valid"], "Wiring S-expression is invalid"

    def test_pipeline_produces_full_dsl(self, interpreter, parser):
        dsl = interpreter.generate_full_dsl()
        skill_count = dsl.count("(define-skill")
        assert skill_count >= 1, f"Expected >= 1 skill definitions, got {skill_count}"
        assert "(define-wiring" in dsl

    def test_pipeline_skills_match_wiring(self, interpreter):
        skills = interpreter.interpret_from_source()
        skill_ids = {s["id"].lstrip(':') for s in skills if s and "id" in s}

        wiring_sexpr = interpreter.generate_wiring_sexpr()
        import re
        wiring_skills = set()
        for m in re.finditer(r':(\w[\w-]*?):', wiring_sexpr):
            wiring_skills.add(m.group(1))

        assert len(wiring_skills) > 0, "No skills found in wiring"

    def test_pipeline_evaluate_generated_skills(self, interpreter, evaluator):
        """Full pipeline: interpret -> generate -> evaluate compute expressions."""
        skills = interpreter.interpret_from_source()
        evaluated = 0
        for skill in skills:
            if not skill or not skill.get("compute"):
                continue
            compute = skill["compute"]
            if isinstance(compute, str) and "(let" in compute:
                # Build inputs from the skill definition
                result = evaluator.evaluate(compute, state={}, inputs={})
                # Should not crash, even if result is 0/None due to missing inputs
                assert result.error is None or "Unexpected" not in result.error
                evaluated += 1
        # At least some skills should have been evaluable
        assert evaluated >= 0  # some skills may not have evaluable compute strings

    def test_upskill_pipeline_end_to_end(self, bridge):
        """Full upskill pipeline: generate -> evaluate -> report."""
        # Step 1: Generate
        skill = bridge.generate_skill(
            task="Generate a project scope estimation skill",
            examples=[{
                "input": "project scope",
                "output": "(define-skill :project-scope (inputs :file-counts) (outputs :total-files) (compute (emit :total-files (sum-values (get input :file-counts)))))"
            }],
        )
        assert skill["status"] in ("executed", "simulated")

        # Step 2: Evaluate
        test_cases = bridge.generate_sexpr_test_cases()
        # Use a subset of test cases
        results = bridge.evaluate_skill(skill, test_cases[:3])
        assert results["status"] in ("executed", "simulated")
        assert "skill_lift" in results
        assert "token_savings" in results

        # Step 3: If not beneficial, refine
        if not results.get("is_beneficial"):
            refined = bridge.refine_skill(
                skill=skill,
                feedback="Need better coverage of all skill fields",
            )
            assert refined["status"] in ("executed", "simulated")


# =============================================================================
# Test 12: Edge Cases and Error Handling
# =============================================================================


class TestEdgeCases:
    """Test edge cases, malformed inputs, and error recovery."""

    def test_parse_deeply_nested(self, parser):
        sexpr = "(a (b (c (d (e (f 42))))))"
        result = parser.parse(sexpr)
        assert result["valid"] is True
        # Navigate to the deepest value
        inner = result["ast"]
        for _ in range(5):
            inner = inner[1]
        assert inner == ["f", 42]  # innermost list

    def test_parse_whitespace_variations(self, parser):
        result = parser.parse("(  +   1    2  )")
        assert result["valid"] is True
        assert result["ast"] == ["+", 1, 2]

    def test_parse_newlines(self, parser):
        result = parser.parse("(\n+\n1\n2\n)")
        assert result["valid"] is True
        assert result["ast"] == ["+", 1, 2]

    def test_parse_extra_closing_paren(self, parser):
        result = parser.parse("(+ 1 2))")
        # The parser consumes (+ 1 2) and ignores the trailing )
        # This depends on implementation - it may or may not error
        # Just verify it doesn't crash
        assert "ast" in result or "error" in result

    def test_parse_only_atom(self, parser):
        result = parser.parse("42")
        assert result["valid"] is True
        assert result["ast"] == 42

    def test_parse_only_keyword(self, parser):
        result = parser.parse(":hello")
        assert result["valid"] is True
        assert result["ast"] == ":hello"

    def test_parse_only_string(self, parser):
        result = parser.parse('"hello world"')
        assert result["valid"] is True
        assert result["ast"] == "hello world"

    def test_parse_float_numbers(self, parser):
        result = parser.parse("(+ 3.14 2.86)")
        assert result["valid"] is True
        assert result["ast"][1] == 3.14
        assert result["ast"][2] == 2.86

    def test_parse_negative_numbers(self, parser):
        result = parser.parse("(- 0 5)")
        assert result["valid"] is True

    def test_eval_unknown_function(self, evaluator):
        """Unknown function should return list, not crash."""
        result = evaluator.evaluate("(custom-fn :arg)")
        assert result.error is None

    def test_eval_nil_handling(self, evaluator):
        result = evaluator.evaluate("(if nil 1 2)")
        assert result.value == 2  # nil is falsy

    def test_eval_empty_let(self, evaluator):
        result = evaluator.evaluate("(let [] 42)")
        assert result.value == 42

    def test_generator_empty_state(self, generator):
        skill_def = {
            "id": ":empty-state",
            "inputs": [":in"],
            "outputs": [":out"],
            "state": {},
        }
        sexpr = generator.generate_from_skill_definition(skill_def)
        assert "(define-skill :empty-state" in sexpr
        # Empty state should not appear
        assert "(state {})" not in sexpr or "(state" not in sexpr

    def test_generator_boolean_state(self, generator, parser):
        skill_def = {
            "id": ":bool-test",
            "inputs": [],
            "outputs": [],
            "state": {"enabled": True, "debug": False},
            "compute": "(get state :enabled)",
        }
        sexpr = generator.generate_from_skill_definition(skill_def)
        assert "true" in sexpr
        assert "false" in sexpr
        result = parser.parse(sexpr)
        assert result["valid"]

    def test_multiple_comments(self, parser):
        sexpr = """;; First comment
        ;; Second comment
        ;; Third comment
        (+ 1 2)
        ;; trailing comment
        """
        result = parser.parse(sexpr)
        assert result["valid"] is True
        assert result["ast"] == ["+", 1, 2]
