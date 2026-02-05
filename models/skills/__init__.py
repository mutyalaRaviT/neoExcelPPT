"""
NeoExcelPPT Models - Skills & S-Expression Generation

This package provides:
- SExprParser: Parse S-expression strings into Python ASTs
- SExprGenerator: Generate S-expression skill definitions
- UpskillBridge: Bridge to Hugging Face upskill library
- LocalhostInterpreter: Extract skills from Phoenix LiveView pages
"""

from models.skills.sexpr_generator import SExprParser, SExprGenerator
from models.skills.skill_definitions import SKILL_REGISTRY
from models.skills.upskill_bridge import UpskillBridge
from models.skills.localhost_interpreter import LocalhostInterpreter

__all__ = [
    "SExprParser",
    "SExprGenerator",
    "UpskillBridge",
    "LocalhostInterpreter",
    "SKILL_REGISTRY",
]
