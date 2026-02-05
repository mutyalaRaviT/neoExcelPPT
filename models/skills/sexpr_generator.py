"""
S-Expression Parser, Generator, and Evaluator for NeoExcelPPT Skills.

This module provides:
- SExprParser: Tokenize, parse, and validate S-expression strings (with map support)
- SExprEvaluator: Actually evaluate S-expressions against a state/env
- SExprGenerator: Generate S-expression skill definitions from structured data
- WiringGenerator: Compose skill wiring as S-expressions
- ActionComposer: Build nested UX action S-expressions
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any


# =============================================================================
# S-Expression Parser (with curly-brace map support)
# =============================================================================


class SExprParser:
    """Parse S-expression strings into Python AST (nested lists/atoms).

    Supports:
    - Parenthesized lists: (+ 1 2)
    - Curly-brace maps: {:key value :key2 value2} -> Python dict
    - Square-bracket vectors: [a b c] -> Python list tagged as vector
    - Keywords: :keyword
    - Strings: "hello"
    - Numbers: 42, 3.14
    - Booleans: true, false
    - Nil: nil
    - Comments: ;; ignored
    """

    def tokenize(self, source: str) -> list[str]:
        """Tokenize an S-expression string into a flat list of tokens."""
        # Handle string literals by temporarily replacing them
        strings: list[str] = []
        def replace_string(match: re.Match) -> str:
            strings.append(match.group(0))
            return f"__STR_{len(strings) - 1}__"

        cleaned = re.sub(r'"[^"]*"', replace_string, source)
        # Remove comments (;; to end of line)
        cleaned = re.sub(r';;[^\n]*', '', cleaned)
        # Pad all delimiters with spaces
        for ch in '(){}[]':
            cleaned = cleaned.replace(ch, f' {ch} ')
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
        elif token == '{':
            return self._parse_map(tokens[1:])
        elif token == '[':
            return self._parse_vector(tokens[1:])
        elif token in (')', '}', ']'):
            raise ValueError(f"Unexpected closing delimiter: {token}")
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

    def _parse_map(self, tokens: list[str]) -> tuple[dict, list[str]]:
        """Parse {key value key value ...} into a Python dict."""
        result: dict[str, Any] = {}
        items: list[Any] = []
        while tokens and tokens[0] != '}':
            expr, tokens = self._parse_expr(tokens)
            items.append(expr)
        if not tokens:
            raise ValueError("Unclosed curly brace")
        # Pair up items: key1 val1 key2 val2 ...
        for i in range(0, len(items) - 1, 2):
            key = items[i]
            val = items[i + 1]
            # Strip leading colon from keyword keys for Python dict
            if isinstance(key, str) and key.startswith(':'):
                key = key[1:]
            result[key] = val
        # Handle odd number of items (last key with no value)
        if len(items) % 2 == 1:
            last = items[-1]
            if isinstance(last, str) and last.startswith(':'):
                result[last[1:]] = None
            else:
                result[str(last)] = None
        return result, tokens[1:]  # skip the '}'

    def _parse_vector(self, tokens: list[str]) -> tuple[list, list[str]]:
        """Parse [a b c] into a Python list."""
        result: list[Any] = []
        while tokens and tokens[0] != ']':
            expr, tokens = self._parse_expr(tokens)
            result.append(expr)
        if not tokens:
            raise ValueError("Unclosed square bracket")
        return result, tokens[1:]  # skip the ']'

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
                    # state arg is now a parsed dict (from {}) or a list
                    raw = item[1]
                    if isinstance(raw, dict):
                        skill["state"] = raw
                    elif isinstance(raw, list):
                        # fallback: treat as flat key-value pairs
                        skill["state"] = raw
                    else:
                        skill["state"] = raw
                elif item[0] == "compute":
                    skill["compute"] = item[1:]
        return skill


# =============================================================================
# S-Expression Evaluator
# =============================================================================


class SExprEvaluator:
    """Evaluate S-expressions against a state and input environment.

    Supports:
    - Arithmetic: (+ a b), (- a b), (* a b), (/ a b)
    - Comparison: (> a b), (< a b), (>= a b), (<= a b), (= a b)
    - Logic: (and a b), (or a b), (not a)
    - State: (get state :key), (get input :channel), (set :key val)
    - Emission: (emit :channel value)
    - Control: (let [bindings] body), (if cond then else), (do expr...)
    - Collections: (sum list), (count list), (map fn list), (merge a b)
    - String: (str a b c)

    Usage:
        evaluator = SExprEvaluator()
        result = evaluator.evaluate(
            "(+ (get input :a) (get input :b))",
            state={"total": 0},
            inputs={"a": 10, "b": 20}
        )
        # result.value == 30
    """

    @dataclass
    class Result:
        value: Any = None
        state: dict[str, Any] = field(default_factory=dict)
        emissions: dict[str, Any] = field(default_factory=dict)
        error: str | None = None

    def __init__(self):
        self.parser = SExprParser()

    def evaluate(
        self,
        source: str | list,
        state: dict[str, Any] | None = None,
        inputs: dict[str, Any] | None = None,
    ) -> "SExprEvaluator.Result":
        """Evaluate an S-expression string or AST.

        Args:
            source: S-expression string or pre-parsed AST
            state: Skill state dict
            inputs: Input channel values

        Returns:
            Result with value, updated state, emissions, and any error.
        """
        env = {
            "state": dict(state or {}),
            "input": dict(inputs or {}),
            "_emissions": {},
        }

        try:
            if isinstance(source, str):
                parsed = self.parser.parse(source)
                if not parsed["valid"]:
                    return self.Result(error=parsed["error"])
                ast = parsed["ast"]
            else:
                ast = source

            value = self._eval(ast, env)
            return self.Result(
                value=value,
                state=env["state"],
                emissions=env["_emissions"],
            )
        except Exception as e:
            return self.Result(
                error=str(e),
                state=env.get("state", {}),
                emissions=env.get("_emissions", {}),
            )

    def _eval(self, ast: Any, env: dict) -> Any:
        # Atoms
        if ast is None or isinstance(ast, (bool, int, float)):
            return ast
        if isinstance(ast, str):
            if ast.startswith(':'):
                return ast  # keyword literal
            # Symbol lookup in local env
            if ast in env:
                return env[ast]
            return ast  # unresolved symbol
        if isinstance(ast, dict):
            return {k: self._eval(v, env) for k, v in ast.items()}

        # Must be a list (S-expression)
        if not isinstance(ast, list) or not ast:
            return ast

        op = ast[0]

        # Arithmetic
        if op == '+':
            vals = [self._eval(a, env) for a in ast[1:]]
            return sum(v for v in vals if isinstance(v, (int, float)))
        if op == '-':
            if len(ast) == 2:
                return -self._eval(ast[1], env)
            a, b = self._eval(ast[1], env), self._eval(ast[2], env)
            return a - b
        if op == '*':
            a, b = self._eval(ast[1], env), self._eval(ast[2], env)
            return a * b
        if op == '/':
            a, b = self._eval(ast[1], env), self._eval(ast[2], env)
            if b == 0:
                return 0
            return a / b

        # Comparison
        if op == '>':
            return self._eval(ast[1], env) > self._eval(ast[2], env)
        if op == '<':
            return self._eval(ast[1], env) < self._eval(ast[2], env)
        if op == '>=':
            return self._eval(ast[1], env) >= self._eval(ast[2], env)
        if op == '<=':
            return self._eval(ast[1], env) <= self._eval(ast[2], env)
        if op == '=':
            return self._eval(ast[1], env) == self._eval(ast[2], env)

        # Logic
        if op == 'and':
            return all(self._eval(a, env) for a in ast[1:])
        if op == 'or':
            return any(self._eval(a, env) for a in ast[1:])
        if op == 'not':
            return not self._eval(ast[1], env)

        # State access
        if op == 'get':
            target = self._eval(ast[1], env)
            key = ast[2] if len(ast) > 2 else None
            if isinstance(target, str) and target == 'state':
                target = env["state"]
            elif isinstance(target, str) and target == 'input':
                target = env["input"]
            if isinstance(target, dict) and key is not None:
                clean_key = key[1:] if isinstance(key, str) and key.startswith(':') else key
                return target.get(clean_key, target.get(key))
            return target

        # State mutation
        if op == 'set':
            key = ast[1]
            val = self._eval(ast[2], env)
            clean_key = key[1:] if isinstance(key, str) and key.startswith(':') else key
            env["state"][clean_key] = val
            return val

        # Emission
        if op == 'emit':
            channel = ast[1]
            val = self._eval(ast[2], env)
            clean_ch = channel[1:] if isinstance(channel, str) and channel.startswith(':') else channel
            env["_emissions"][clean_ch] = val
            return val

        # Let bindings
        if op == 'let':
            bindings = ast[1]  # [name1 expr1 name2 expr2 ...]
            local_env = dict(env)
            if isinstance(bindings, list):
                for i in range(0, len(bindings) - 1, 2):
                    name = bindings[i]
                    val = self._eval(bindings[i + 1], local_env)
                    local_env[name] = val
            # Evaluate body expressions
            result = None
            for body_expr in ast[2:]:
                result = self._eval(body_expr, local_env)
            # Propagate state/emissions back
            env["state"] = local_env["state"]
            env["_emissions"] = local_env["_emissions"]
            return result

        # If
        if op == 'if':
            cond = self._eval(ast[1], env)
            if cond:
                return self._eval(ast[2], env)
            elif len(ast) > 3:
                return self._eval(ast[3], env)
            return None

        # Do (sequence)
        if op in ('do', 'seq'):
            result = None
            for expr in ast[1:]:
                result = self._eval(expr, env)
            return result

        # Collections
        if op == 'sum':
            lst = self._eval(ast[1], env)
            if isinstance(lst, (list, tuple)):
                return sum(v for v in lst if isinstance(v, (int, float)))
            if isinstance(lst, dict):
                return sum(v for v in lst.values() if isinstance(v, (int, float)))
            return 0
        if op == 'count':
            lst = self._eval(ast[1], env)
            return len(lst) if hasattr(lst, '__len__') else 0
        if op == 'merge':
            a = self._eval(ast[1], env)
            b = self._eval(ast[2], env)
            if isinstance(a, dict) and isinstance(b, dict):
                return {**a, **b}
            return b
        if op == 'assoc':
            m = self._eval(ast[1], env)
            key = ast[2]
            val = self._eval(ast[3], env)
            clean_key = key[1:] if isinstance(key, str) and key.startswith(':') else key
            if isinstance(m, dict):
                return {**m, clean_key: val}
            return {clean_key: val}

        # String concat
        if op == 'str':
            parts = [str(self._eval(a, env)) for a in ast[1:]]
            return "".join(parts)

        # Sum values of a map
        if op == 'sum-values':
            m = self._eval(ast[1], env)
            if isinstance(m, dict):
                return sum(v for v in m.values() if isinstance(v, (int, float)))
            return 0

        # Unknown function - return list as-is
        return [self._eval(a, env) for a in ast]


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
