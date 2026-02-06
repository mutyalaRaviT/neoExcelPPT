"""
Skill Definitions Registry for NeoExcelPPT.

This module contains the canonical skill definitions extracted from the
existing Elixir codebase (localhost:4000) and expressed as Python dicts
that can be converted to S-expressions.

Each skill definition mirrors the structure of the Elixir GenServer skills
found in lib/neo_excel_ppt/skills/*.ex.
"""

from __future__ import annotations
from typing import Any


# =============================================================================
# Core Skill Definitions (from localhost:4000 Phoenix LiveView)
# =============================================================================

PROJECT_SCOPE_SKILL: dict[str, Any] = {
    "id": ":project-scope",
    "name": "Project Scope",
    "description": "Manages project file counts (simple/medium/complex) and computes totals and breakdowns.",
    "inputs": [":file-counts"],
    "outputs": [":total-files", ":component-breakdown"],
    "state": {
        "simple": 0,
        "medium": 0,
        "complex": 0,
    },
    "compute": (
        '(let [files (get input :file-counts)\n'
        '      simple (get files :simple)\n'
        '      medium (get files :medium)\n'
        '      complex (get files :complex)\n'
        '      total (+ simple medium complex)]\n'
        '  (set :simple simple)\n'
        '  (set :medium medium)\n'
        '  (set :complex complex)\n'
        '  (emit :total-files total)\n'
        '  (emit :component-breakdown\n'
        '    {:simple simple :medium medium :complex complex}))'
    ),
    "ui": {
        "section": "project-scope",
        "elements": [
            {"id": "project-scope-total-files", "type": "display", "bind": ":total-files"},
            {"id": "project-scope-simple-count", "type": "number-input", "bind": ":file-counts.simple"},
            {"id": "project-scope-medium-count", "type": "number-input", "bind": ":file-counts.medium"},
            {"id": "project-scope-complex-count", "type": "number-input", "bind": ":file-counts.complex"},
        ],
    },
}

COMPONENT_CALCULATOR_SKILL: dict[str, Any] = {
    "id": ":component-calculator",
    "name": "Component Calculator",
    "description": "Scales file counts by component multipliers and applies automation percentages.",
    "inputs": [":file-count", ":breakdown", ":automation-pct"],
    "outputs": [":scaled-effort", ":component-days"],
    "state": {
        "base-hours-per-file": 15,
    },
    "compute": (
        '(let [files (get input :file-count)\n'
        '      hours (get state :base-hours-per-file)\n'
        '      auto-pct (get input :automation-pct)\n'
        '      base-effort (* files hours)\n'
        '      scaled (* base-effort (- 1 (/ auto-pct 100)))]\n'
        '  (emit :scaled-effort scaled)\n'
        '  (emit :component-days (/ scaled 8)))'
    ),
    "ui": {
        "section": "component-calculator",
        "elements": [
            {"id": "component-simple-count", "type": "number-input", "bind": ":file-count.simple"},
            {"id": "component-medium-count", "type": "number-input", "bind": ":file-count.medium"},
            {"id": "component-complex-count", "type": "number-input", "bind": ":file-count.complex"},
        ],
    },
}

ACTIVITY_CALCULATOR_SKILL: dict[str, Any] = {
    "id": ":activity-calculator",
    "name": "Activity Calculator",
    "description": "Manages activity/task records with team assignments and computes totals.",
    "inputs": [":activity-update", ":team-assignment"],
    "outputs": [":activity-totals", ":team-effort"],
    "state": {
        "activities": {},
    },
    "compute": (
        '(let [update (get input :activity-update)]\n'
        '  (set :activities (merge (get state :activities) update))\n'
        '  (emit :activity-totals (sum-values (get state :activities))))'
    ),
    "ui": {
        "section": "activities-table",
        "elements": [
            {"id": "activities-totals", "type": "display-row"},
            {"id": "activities-total-auto-pct", "type": "display", "bind": ":totals.avg-auto-pct"},
            {"id": "activities-total-base-days", "type": "display", "bind": ":totals.base-days"},
            {"id": "activities-total-final-days", "type": "display", "bind": ":totals.final-days"},
        ],
    },
}

EFFORT_AGGREGATOR_SKILL: dict[str, Any] = {
    "id": ":effort-aggregator",
    "name": "Effort Aggregator",
    "description": "Aggregates component effort, activity effort, and buffer days into total estimate.",
    "inputs": [":component-effort", ":activity-effort", ":buffer-days"],
    "outputs": [":total-days", ":effort-breakdown"],
    "state": {
        "component": 0,
        "activity": 0,
        "buffer": 0,
    },
    "compute": (
        '(let [comp (get input :component-effort)\n'
        '      act (get input :activity-effort)\n'
        '      buf (get input :buffer-days)\n'
        '      total (+ comp act buf)]\n'
        '  (emit :total-days total)\n'
        '  (emit :effort-breakdown {:component comp :activity act :buffer buf}))'
    ),
    "ui": {
        "section": "effort-breakdown",
        "elements": [
            {"id": "effort-manual-days", "type": "display", "bind": ":manual-days"},
            {"id": "effort-automation-days", "type": "display", "bind": ":automation-days"},
            {"id": "effort-total-days", "type": "display", "bind": ":total-base-days"},
        ],
    },
}

BUFFER_CALCULATOR_SKILL: dict[str, Any] = {
    "id": ":buffer-calculator",
    "name": "Buffer Calculator",
    "description": "Computes project buffers (leave, dependency, learning curve) as percentage of base days.",
    "inputs": [":base-days", ":buffer-config"],
    "outputs": [":buffer-days", ":buffer-breakdown"],
    "state": {
        "leave-pct": 10,
        "dependency-pct": 15,
        "learning-pct": 20,
    },
    "compute": (
        '(let [base (get input :base-days)\n'
        '      leave (* base (/ (get state :leave-pct) 100))\n'
        '      dep (* base (/ (get state :dependency-pct) 100))\n'
        '      learn (* base (/ (get state :learning-pct) 100))]\n'
        '  (emit :buffer-days (+ leave dep learn))\n'
        '  (emit :buffer-breakdown {:leave leave :dependency dep :learning learn}))'
    ),
    "ui": {
        "section": "proposed-buffers",
        "elements": [
            {"id": "buffer-leave", "type": "display-row", "bind": ":buffers.leave"},
            {"id": "buffer-dependency", "type": "display-row", "bind": ":buffers.dependency"},
            {"id": "buffer-learning", "type": "display-row", "bind": ":buffers.learning"},
        ],
    },
}


# =============================================================================
# Default Wiring (from SkillManager @default_wiring)
# =============================================================================

DEFAULT_WIRING: list[dict[str, str]] = [
    {
        "from_skill": "project-scope",
        "from_channel": "total-files",
        "to_skill": "component-calculator",
        "to_channel": "file-count",
    },
    {
        "from_skill": "project-scope",
        "from_channel": "component-breakdown",
        "to_skill": "component-calculator",
        "to_channel": "breakdown",
    },
    {
        "from_skill": "component-calculator",
        "from_channel": "scaled-effort",
        "to_skill": "effort-aggregator",
        "to_channel": "component-effort",
    },
    {
        "from_skill": "activity-calculator",
        "from_channel": "activity-totals",
        "to_skill": "effort-aggregator",
        "to_channel": "activity-effort",
    },
    {
        "from_skill": "effort-aggregator",
        "from_channel": "total-days",
        "to_skill": "buffer-calculator",
        "to_channel": "base-days",
    },
]


# =============================================================================
# Skill Registry
# =============================================================================

SKILL_REGISTRY: dict[str, dict[str, Any]] = {
    "project-scope": PROJECT_SCOPE_SKILL,
    "component-calculator": COMPONENT_CALCULATOR_SKILL,
    "activity-calculator": ACTIVITY_CALCULATOR_SKILL,
    "effort-aggregator": EFFORT_AGGREGATOR_SKILL,
    "buffer-calculator": BUFFER_CALCULATOR_SKILL,
}


def get_all_skills() -> list[dict[str, Any]]:
    """Return all registered skill definitions."""
    return list(SKILL_REGISTRY.values())


def get_skill(skill_id: str) -> dict[str, Any] | None:
    """Get a skill definition by ID."""
    # Strip leading colon if present
    clean_id = skill_id.lstrip(':')
    return SKILL_REGISTRY.get(clean_id)


def get_skill_ids() -> list[str]:
    """Return all registered skill IDs."""
    return list(SKILL_REGISTRY.keys())
