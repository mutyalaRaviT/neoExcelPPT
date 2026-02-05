"""
Localhost:4000 Interpreter for NeoExcelPPT.

This module interprets the Phoenix LiveView page served at localhost:4000
and extracts skill definitions from the HTML/HEEx structure.

Since the server may not be running, this module also works by directly
analyzing the Elixir source files (project_live.ex and skill modules)
to extract the same information.

The interpreter produces:
- Skill definitions (id, inputs, outputs, state, compute)
- UI element mappings (HTML elements -> skill bindings)
- Wiring configurations (how skills connect)
"""

from __future__ import annotations

import os
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from models.skills.sexpr_generator import SExprGenerator, SExprParser


# =============================================================================
# UI Element Extraction
# =============================================================================


@dataclass
class UIElement:
    """An interactive UI element extracted from the page."""

    element_id: str
    element_type: str  # "input", "display", "button", "table", "section"
    html_type: str  # "number", "checkbox", "text", "span", "div"
    bind_channel: str | None = None
    phx_event: str | None = None
    section: str | None = None
    label: str | None = None


@dataclass
class PageSection:
    """A section of the page (e.g., Project Scope, Activities)."""

    section_id: str
    title: str
    elements: list[UIElement] = field(default_factory=list)
    skill_id: str | None = None


# =============================================================================
# Localhost Interpreter
# =============================================================================


class LocalhostInterpreter:
    """Interpret localhost:4000 (or its source) into skill definitions.

    Usage:
        interpreter = LocalhostInterpreter()

        # From Elixir source files (when server is not running)
        skills = interpreter.interpret_from_source()

        # From HTML content (when server is running)
        skills = interpreter.interpret_from_html(html_content)
    """

    PROJECT_ROOT = Path("/home/user/neoExcelPPT")

    def __init__(self):
        self.generator = SExprGenerator()
        self.parser = SExprParser()

    def interpret_from_source(self) -> list[dict[str, Any]]:
        """Interpret skills directly from Elixir source files.

        This is the primary method when localhost:4000 is not running.
        It reads the LiveView and skill module source to extract
        skill definitions, UI elements, and wiring.
        """
        skills: list[dict[str, Any]] = []

        # Extract from project_live.ex
        project_live = self._read_source("lib/neo_excel_ppt_web/live/project_live.ex")
        if project_live:
            sections = self._extract_sections(project_live)
            for section in sections:
                skill = self._section_to_skill(section)
                if skill:
                    skills.append(skill)

        # Extract from individual skill modules
        skill_dir = self.PROJECT_ROOT / "lib" / "neo_excel_ppt" / "skills"
        if skill_dir.exists():
            for skill_file in skill_dir.glob("*_skill.ex"):
                source = skill_file.read_text()
                skill = self._elixir_skill_to_definition(source, skill_file.stem)
                if skill:
                    skills.append(skill)

        return skills

    def interpret_from_html(self, source_or_path: str) -> list[dict[str, Any]]:
        """Interpret skills from HTML content or a source file path.

        Args:
            source_or_path: Either raw HTML/HEEx content, or a relative
                           path to a source file in the project.
        """
        # If it looks like a file path, read it
        if not source_or_path.strip().startswith('<') and '/' in source_or_path:
            full_path = self.PROJECT_ROOT / source_or_path
            if full_path.exists():
                source_or_path = full_path.read_text()
            else:
                return []

        sections = self._extract_sections(source_or_path)
        return [self._section_to_skill(s) for s in sections if s]

    def extract_ui_elements(self, source: str) -> list[UIElement]:
        """Extract all interactive UI elements from source."""
        elements: list[UIElement] = []

        # Find input elements with IDs
        for m in re.finditer(
            r'<input[^>]*id="([^"]+)"[^>]*type="(\w+)"[^>]*(?:phx-\w+="([^"]+)")?',
            source,
        ):
            elements.append(UIElement(
                element_id=m.group(1),
                element_type="input",
                html_type=m.group(2),
                phx_event=m.group(3),
            ))

        # Find display elements with IDs (spans, divs with data bindings)
        for m in re.finditer(
            r'<(?:span|p|div)[^>]*id="([^"]+)"[^>]*class="[^"]*font-mono[^"]*"',
            source,
        ):
            elements.append(UIElement(
                element_id=m.group(1),
                element_type="display",
                html_type="span",
            ))

        # Find sections with IDs
        for m in re.finditer(
            r'<div[^>]*id="([^"]+)"[^>]*class="[^"]*(?:bg-white|rounded-xl)[^"]*"',
            source,
        ):
            elements.append(UIElement(
                element_id=m.group(1),
                element_type="section",
                html_type="div",
            ))

        # Find buttons with IDs and phx-click events
        for m in re.finditer(
            r'<button[^>]*id="([^"]+)"[^>]*phx-click="([^"]+)"',
            source,
        ):
            elements.append(UIElement(
                element_id=m.group(1),
                element_type="button",
                html_type="button",
                phx_event=m.group(2),
            ))

        return elements

    def generate_skill_sexprs(self) -> list[str]:
        """Generate S-expressions for all skills found in the source.

        Returns a list of S-expression strings, one per skill.
        """
        skills = self.interpret_from_source()
        return [
            self.generator.generate_from_skill_definition(s)
            for s in skills
            if s
        ]

    def generate_wiring_sexpr(self) -> str:
        """Generate the wiring S-expression from source analysis."""
        wiring_source = self._read_source(
            "lib/neo_excel_ppt/skills/skill_manager.ex"
        )
        connections = self._extract_wiring(wiring_source) if wiring_source else []
        return self.generator.generate_wiring(connections)

    def generate_full_dsl(self) -> str:
        """Generate the complete DSL (all skills + wiring)."""
        parts = [
            ";; NeoExcelPPT Skills DSL",
            ";; Auto-generated from localhost:4000 source analysis",
            "",
        ]

        # Add all skill definitions
        for sexpr in self.generate_skill_sexprs():
            parts.append(sexpr)
            parts.append("")

        # Add wiring
        parts.append(";; Skill Wiring")
        parts.append(self.generate_wiring_sexpr())

        return "\n".join(parts)

    # =========================================================================
    # Private Helpers
    # =========================================================================

    def _read_source(self, relative_path: str) -> str | None:
        """Read a source file from the project."""
        full_path = self.PROJECT_ROOT / relative_path
        if full_path.exists():
            return full_path.read_text()
        return None

    def _extract_sections(self, source: str) -> list[PageSection]:
        """Extract page sections from HEEx/HTML source."""
        sections: list[PageSection] = []

        # Match section components in the render function
        section_patterns = [
            (r'id="project-scope"', "Project Scope", "project-scope"),
            (r'id="activities-table"', "Activities & Responsibilities", "activities-table"),
            (r'id="component-calculator"', "Component Scaling Calculator", "component-calculator"),
            (r'id="effort-breakdown"', "Effort Breakdown", "effort-breakdown"),
            (r'id="proposed-buffers"', "Proposed Buffers", "proposed-buffers"),
            (r'id="team-composition"', "Team Composition", "team-composition"),
        ]

        for pattern, title, section_id in section_patterns:
            if re.search(pattern, source):
                section = PageSection(
                    section_id=section_id,
                    title=title,
                )
                # Extract elements within this section
                section.elements = self._extract_section_elements(
                    source, section_id
                )
                sections.append(section)

        return sections

    def _extract_section_elements(
        self, source: str, section_id: str
    ) -> list[UIElement]:
        """Extract UI elements that belong to a specific section."""
        elements = self.extract_ui_elements(source)
        return [e for e in elements if e.element_id.startswith(section_id)]

    def _section_to_skill(self, section: PageSection) -> dict[str, Any] | None:
        """Convert a page section into a skill definition."""
        # Map section IDs to skill configurations
        section_skill_map: dict[str, dict[str, Any]] = {
            "project-scope": {
                "id": ":project-scope",
                "name": "Project Scope",
                "description": "Input file counts and compute totals/breakdowns",
                "inputs": [":file-counts"],
                "outputs": [":total-files", ":component-breakdown"],
                "state": {"simple": 0, "medium": 0, "complex": 0},
                "compute": "(emit :total-files (sum (get input :file-counts)))",
            },
            "activities-table": {
                "id": ":activity-calculator",
                "name": "Activity Calculator",
                "description": "Track activities with team assignments and compute totals",
                "inputs": [":activity-update", ":team-assignment"],
                "outputs": [":activity-totals", ":team-effort"],
                "state": {"activities": {}},
                "compute": "(emit :activity-totals (sum-values (get state :activities)))",
            },
            "component-calculator": {
                "id": ":component-calculator",
                "name": "Component Calculator",
                "description": "Scale file counts by complexity multipliers",
                "inputs": [":file-count", ":breakdown", ":automation-pct"],
                "outputs": [":scaled-effort", ":component-days"],
                "state": {"base-hours-per-file": 15},
                "compute": "(emit :scaled-effort (* (get input :file-count) (get state :base-hours-per-file)))",
            },
            "effort-breakdown": {
                "id": ":effort-aggregator",
                "name": "Effort Aggregator",
                "description": "Aggregate all effort sources into total days",
                "inputs": [":component-effort", ":activity-effort", ":buffer-days"],
                "outputs": [":total-days", ":effort-breakdown"],
                "state": {"component": 0, "activity": 0, "buffer": 0},
                "compute": "(emit :total-days (+ (get input :component-effort) (get input :activity-effort) (get input :buffer-days)))",
            },
            "proposed-buffers": {
                "id": ":buffer-calculator",
                "name": "Buffer Calculator",
                "description": "Compute project buffers as percentage of base days",
                "inputs": [":base-days", ":buffer-config"],
                "outputs": [":buffer-days", ":buffer-breakdown"],
                "state": {"leave-pct": 10, "dependency-pct": 15, "learning-pct": 20},
                "compute": "(emit :buffer-days (+ (* (get input :base-days) 0.1) (* (get input :base-days) 0.15) (* (get input :base-days) 0.2)))",
            },
            "team-composition": {
                "id": ":team-manager",
                "name": "Team Composition",
                "description": "Track team member allocation across skills",
                "inputs": [":team-update"],
                "outputs": [":team-totals"],
                "state": {"automation": 0, "testing": 0, "total": 0},
                "compute": "(emit :team-totals (get state))",
            },
        }

        return section_skill_map.get(section.section_id)

    def _elixir_skill_to_definition(
        self, source: str, module_name: str
    ) -> dict[str, Any] | None:
        """Extract a skill definition from an Elixir skill module."""
        # Extract skill_id
        id_match = re.search(r'def skill_id.*?do\s*:(\w+)', source, re.DOTALL)
        if not id_match:
            return None
        skill_id = id_match.group(1)

        # Extract input_channels
        inputs_match = re.search(
            r'def input_channels.*?do\s*\[([^\]]*)\]', source, re.DOTALL
        )
        inputs = []
        if inputs_match:
            inputs = [
                f":{ch.strip().strip(':')}"
                for ch in inputs_match.group(1).split(',')
                if ch.strip()
            ]

        # Extract output_channels
        outputs_match = re.search(
            r'def output_channels.*?do\s*\[([^\]]*)\]', source, re.DOTALL
        )
        outputs = []
        if outputs_match:
            outputs = [
                f":{ch.strip().strip(':')}"
                for ch in outputs_match.group(1).split(',')
                if ch.strip()
            ]

        # Extract initial_state keys
        state_match = re.search(
            r'def initial_state.*?%\{([^}]*)\}', source, re.DOTALL
        )
        state = {}
        if state_match:
            for pair in re.finditer(r'(\w+):\s*([^,}]+)', state_match.group(1)):
                key = pair.group(1)
                val = pair.group(2).strip()
                try:
                    state[key] = int(val)
                except ValueError:
                    try:
                        state[key] = float(val)
                    except ValueError:
                        state[key] = val

        return {
            "id": f":{skill_id.replace('_', '-')}",
            "name": module_name.replace('_skill', '').replace('_', ' ').title(),
            "description": f"Skill extracted from {module_name}.ex",
            "inputs": inputs,
            "outputs": outputs,
            "state": state,
            "compute": None,  # Compute logic requires deeper Elixir AST analysis
            "source_file": f"{module_name}.ex",
        }

    def _extract_wiring(self, source: str) -> list[dict[str, str]]:
        """Extract wiring connections from SkillManager source."""
        connections: list[dict[str, str]] = []

        # Match patterns like {:project_scope, :total_files} => [{:component_calculator, :file_count}]
        for m in re.finditer(
            r'\{:(\w+),\s*:(\w+)\}\s*=>\s*\[(.*?)\]',
            source,
            re.DOTALL,
        ):
            from_skill = m.group(1).replace('_', '-')
            from_channel = m.group(2).replace('_', '-')

            # Parse targets
            for target in re.finditer(r'\{:(\w+),\s*:(\w+)\}', m.group(3)):
                connections.append({
                    "from_skill": from_skill,
                    "from_channel": from_channel,
                    "to_skill": target.group(1).replace('_', '-'),
                    "to_channel": target.group(2).replace('_', '-'),
                })

        return connections
