"""
NeoExcelPPT Models - Skills & S-Expression Generation

This package provides:
- SExprParser: Parse S-expression strings into Python ASTs (with map/vector support)
- SExprEvaluator: Actually evaluate S-expressions against a state/env
- SExprGenerator: Generate S-expression skill definitions
- UpskillBridge: Bridge to Hugging Face upskill library (live + simulation modes)
- LocalhostInterpreter: Extract skills from Phoenix LiveView pages
"""

from models.skills.sexpr_generator import SExprParser, SExprGenerator, SExprEvaluator
from models.skills.skill_definitions import SKILL_REGISTRY
from models.skills.upskill_bridge import UpskillBridge
from models.skills.localhost_interpreter import LocalhostInterpreter

__all__ = [
    "SExprParser",
    "SExprGenerator",
    "SExprEvaluator",
    "UpskillBridge",
    "LocalhostInterpreter",
    "SKILL_REGISTRY",
]
