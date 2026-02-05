"""
S-Expression Parser and Generator for NeoExcelPPT Skills.

This module provides:
- SExprParser: Tokenize, parse, and validate S-expression strings
- SExprGenerator: Generate S-expression skill definitions from structured data
- WiringGenerator: Compose skill wiring as S-expressions
- ActionComposer: Build nested UX action S-expressions
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any


# =============================================================================
# S-Expression Parser
# =============================================================================


class SExprParser:
    """Parse S-expression strings into Python AST (nested lists/atoms)."""

    def tokenize(self, source: str) -> list[str]:
        """Tokenize an S-expression string into a flat list of tokens."""
        # Handle string literals by temporarily replacing them
        strings: list[str] = []
        def replace_string(match: re.Match) -> str:
            strings.append(match.group(0))
            return f"__STR_{len(strings) - 1}__"

        cleaned = re.sub(r'"[^"]*"', replace_string, source)
        # Remove comments (lines starting with ;;)
        cleaned = re.sub(r';;[^\n]*', '', cleaned)
        # Pad parens with spaces
        cleaned = cleaned.replace('(', ' ( ').replace(')', ' ) ')
        tokens = cleaned.split()
        # Restore string literals
        restored = []
        for t in tokens:
            m = re.match(r'^__STR_(\d+)__$', t)
            if m:
                restored.append(strings[int(m.group(1))])
            else:
                restored.append(t)
        return restored

    def parse(self, source: str) -> dict[str, Any]:
        """Parse an S-expression string and return a result dict.

        Returns:
            {"valid": True, "ast": <parsed AST>, "skill_id": <id if skill def>}
            or {"valid": False, "error": "<message>"}
        """
        try:
            tokens = self.tokenize(source)
            if not tokens:
                return {"valid": False, "error": "Empty input"}
            ast, remaining = self._parse_expr(tokens)
            result: dict[str, Any] = {"valid": True, "ast": ast}
            # Extract skill_id if this is a define-skill form
            if isinstance(ast, list) and len(ast) >= 2 and ast[0] == "define-skill":
                result["skill_id"] = ast[1]
            return result
        except Exception as e:
            return {"valid": False, "error": str(e)}

    def _parse_expr(self, tokens: list[str]) -> tuple[Any, list[str]]:
        if not tokens:
            raise ValueError("Unexpected end of input")
        token = tokens[0]
        if token == '(':
            return self._parse_list(tokens[1:])
        elif token == ')':
            raise ValueError("Unexpected closing parenthesis")
        else:
            return self._parse_atom(tokens[0]), tokens[1:]

    def _parse_list(self, tokens: list[str]) -> tuple[list, list[str]]:
        result: list[Any] = []
        while tokens and tokens[0] != ')':
            expr, tokens = self._parse_expr(tokens)
            result.append(expr)
        if not tokens:
            raise ValueError("Unclosed parenthesis")
        return result, tokens[1:]  # skip the ')'

    def _parse_atom(self, token: str) -> Any:
        # Keywords (:keyword)
        if token.startswith(':'):
            return token
        # Strings
        if token.startswith('"') and token.endswith('"'):
            return token[1:-1]
        # Booleans
        if token == 'true':
            return True
        if token == 'false':
            return False
        if token == 'nil':
            return None
        # Numbers
        try:
            return int(token)
        except ValueError:
            pass
        try:
            return float(token)
        except ValueError:
            pass
        # Symbol
        return token

    def ast_to_skill(self, ast: list) -> dict[str, Any] | None:
        """Convert a parsed skill AST into a skill definition dict."""
        if not isinstance(ast, list) or len(ast) < 2 or ast[0] != "define-skill":
            return None
        skill: dict[str, Any] = {
            "id": ast[1],
            "inputs": [],
            "outputs": [],
            "state": {},
            "compute": None,
        }
        for item in ast[2:]:
            if isinstance(item, list) and item:
                if item[0] == "inputs":
                    skill["inputs"] = item[1:]
                elif item[0] == "outputs":
                    skill["outputs"] = item[1:]
                elif item[0] == "state" and len(item) > 1:
                    skill["state"] = item[1]
                elif item[0] == "compute":
                    skill["compute"] = item[1:]
        return skill


# =============================================================================
# S-Expression Generator
# =============================================================================


class SExprGenerator:
    """Generate S-expression strings from structured skill definitions."""

    def __init__(self, indent_size: int = 2):
        self.indent_size = indent_size

    def generate_from_skill_definition(self, skill_def: dict[str, Any]) -> str:
        """Generate a complete (define-skill ...) S-expression from a dict."""
        lines: list[str] = []
        sid = skill_def.get("id", ":unknown")
        lines.append(f"(define-skill {sid}")

        # Inputs
        inputs = skill_def.get("inputs", [])
        if inputs:
            inputs_str = " ".join(inputs)
            lines.append(f"  (inputs {inputs_str})")

        # Outputs
        outputs = skill_def.get("outputs", [])
        if outputs:
            outputs_str = " ".join(outputs)
            lines.append(f"  (outputs {outputs_str})")

        # State
        state = skill_def.get("state", {})
        if state:
            state_str = self._format_map(state)
            lines.append(f"  (state {state_str})")

        # Compute
        compute = skill_def.get("compute")
        if compute:
            if isinstance(compute, str):
                lines.append(f"  (compute")
                lines.append(f"    {compute}))")
            elif isinstance(compute, list):
                compute_str = self._format_expr(compute, depth=2)
                lines.append(f"  (compute")
                lines.append(f"    {compute_str}))")
            else:
                lines.append(f"  (compute {compute}))")
        else:
            # Close the define-skill
            lines[-1] += ")"

        return "\n".join(lines)

    def generate_wiring(self, connections: list[dict[str, str]]) -> str:
        """Generate a (define-wiring ...) S-expression."""
        lines = ["(define-wiring"]
        for conn in connections:
            src = f":{conn['from_skill']}:{conn['from_channel']}"
            tgt = f":{conn['to_skill']}:{conn['to_channel']}"
            lines.append(f"  (connect {src} -> {tgt})")
        lines[-1] += ")"
        return "\n".join(lines)

    def skill_doc_to_sexpr(self, skill_doc: str) -> str:
        """Convert a SKILL.md document text into an S-expression.

        This is a heuristic converter that looks for skill patterns
        in markdown and extracts structured definitions.
        """
        # Extract skill name
        name_match = re.search(r'#\s+(?:Skill:\s*)?(\S+)', skill_doc)
        name = name_match.group(1).lower().replace(' ', '-') if name_match else "unknown"

        # Look for any S-expression blocks already in the doc
        sexpr_match = re.search(r'\(define-skill[^)]*(?:\([^)]*\))*\)', skill_doc, re.DOTALL)
        if sexpr_match:
            return sexpr_match.group(0)

        # Build from heuristics
        inputs = re.findall(r'[Ii]nput[s]?:\s*(.+)', skill_doc)
        outputs = re.findall(r'[Oo]utput[s]?:\s*(.+)', skill_doc)

        skill_def = {
            "id": f":{name}",
            "inputs": [f":{w.strip().lower().replace(' ', '-')}" for w in inputs[0].split(',')] if inputs else [":input"],
            "outputs": [f":{w.strip().lower().replace(' ', '-')}" for w in outputs[0].split(',')] if outputs else [":output"],
            "state": {},
            "compute": "(emit :output (get input :input))",
        }
        return self.generate_from_skill_definition(skill_def)

    def _format_map(self, m: dict) -> str:
        pairs = []
        for k, v in m.items():
            key = f":{k}" if not str(k).startswith(':') else k
            val = self._format_value(v)
            pairs.append(f"{key} {val}")
        return "{" + " ".join(pairs) + "}"

    def _format_value(self, v: Any) -> str:
        if isinstance(v, bool):
            return "true" if v else "false"
        if v is None:
            return "nil"
        if isinstance(v, (int, float)):
            return str(v)
        if isinstance(v, str):
            if v.startswith(':') or v.startswith('('):
                return v
            return f'"{v}"'
        if isinstance(v, dict):
            return self._format_map(v)
        if isinstance(v, list):
            return "(" + " ".join(self._format_value(x) for x in v) + ")"
        return str(v)

    def _format_expr(self, expr: list, depth: int = 0) -> str:
        if not expr:
            return "()"
        parts = []
        for item in expr:
            if isinstance(item, list):
                parts.append(self._format_expr(item, depth + 1))
            else:
                parts.append(self._format_value(item))
        return "(" + " ".join(parts) + ")"


# =============================================================================
# Wiring Generator
# =============================================================================


class WiringGenerator:
    """Generate skill wiring S-expressions."""

    def __init__(self):
        self.connections: list[dict[str, str]] = []

    def connect(self, from_skill: str, from_channel: str,
                to_skill: str, to_channel: str) -> "WiringGenerator":
        self.connections.append({
            "from_skill": from_skill,
            "from_channel": from_channel,
            "to_skill": to_skill,
            "to_channel": to_channel,
        })
        return self

    def to_sexpr(self) -> str:
        gen = SExprGenerator()
        return gen.generate_wiring(self.connections)

    def clear(self) -> None:
        self.connections.clear()


# =============================================================================
# Action Composer
# =============================================================================


@dataclass
class SExprNode:
    """A node in an S-expression action tree."""

    operator: str
    operands: list[Any] = field(default_factory=list)

    def to_sexpr(self, depth: int = 0) -> str:
        indent = "  " * depth
        if not self.operands:
            return f"({self.operator})"
        parts = [self.operator]
        for op in self.operands:
            if isinstance(op, SExprNode):
                parts.append(op.to_sexpr(depth + 1))
            elif isinstance(op, str):
                if op.startswith(':') or op.startswith('('):
                    parts.append(op)
                else:
                    parts.append(f'"{op}"')
            else:
                parts.append(str(op))
        return "(" + " ".join(parts) + ")"


class ActionComposer:
    """Compose nested UX action S-expressions."""

    def call(self, fn_name: str, *args: Any) -> SExprNode:
        return SExprNode(operator=fn_name, operands=list(args))

    def seq(self, *actions: SExprNode) -> SExprNode:
        return SExprNode(operator="seq", operands=list(actions))

    def if_then_else(self, cond: SExprNode, then: SExprNode,
                     else_: SExprNode) -> SExprNode:
        return SExprNode(operator="if", operands=[cond, then, else_])

    def on_click(self, action: SExprNode) -> SExprNode:
        return SExprNode(operator="on-click", operands=[action])

    def on_change(self, action: SExprNode) -> SExprNode:
        return SExprNode(operator="on-change", operands=[action])

    def on_blur(self, action: SExprNode) -> SExprNode:
        return SExprNode(operator="on-blur", operands=[action])

    def debounce(self, ms: int, action: SExprNode) -> SExprNode:
        return SExprNode(operator="debounce", operands=[ms, action])
