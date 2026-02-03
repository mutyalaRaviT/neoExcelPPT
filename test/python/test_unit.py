"""
Unit Tests for NeoExcelPPT - No browser required.

These tests verify:
- Test configuration is correct
- Element ID constants are properly defined
- Helper functions work correctly
"""

import pytest
from conftest import IDs, BASE_URL, ElementIDs


class TestConfiguration:
    """Tests for test configuration."""

    def test_base_url_is_set(self):
        """Test that BASE_URL is configured."""
        assert BASE_URL is not None
        assert BASE_URL.startswith("http")
        assert "localhost" in BASE_URL or "127.0.0.1" in BASE_URL

    def test_base_url_has_port(self):
        """Test that BASE_URL includes a port."""
        assert ":" in BASE_URL
        # Default Phoenix port is 4000
        assert "4000" in BASE_URL or "4002" in BASE_URL


class TestElementIDs:
    """Tests for Element ID constants."""

    def test_navigation_ids_defined(self):
        """Test that navigation IDs are defined."""
        assert IDs.NAV_MAIN == "main-nav"
        assert IDs.NAV_PROJECT == "nav-project"
        assert IDs.NAV_TIMELINE == "nav-timeline"
        assert IDs.NAV_SKILLS == "nav-skills"

    def test_project_scope_ids_defined(self):
        """Test that project scope IDs are defined."""
        assert IDs.PROJECT_SCOPE == "project-scope"
        assert IDs.PROJECT_SCOPE_TOTAL_FILES == "project-scope-total-files"
        assert IDs.PROJECT_SCOPE_PROJECT_TYPE == "project-scope-project-type"
        assert IDs.PROJECT_SCOPE_SIMPLE_COUNT == "project-scope-simple-count"
        assert IDs.PROJECT_SCOPE_MEDIUM_COUNT == "project-scope-medium-count"
        assert IDs.PROJECT_SCOPE_COMPLEX_COUNT == "project-scope-complex-count"

    def test_activities_ids_defined(self):
        """Test that activities IDs are defined."""
        assert IDs.ACTIVITIES_TABLE == "activities-table"
        assert IDs.ACTIVITIES_TOTALS == "activities-totals"
        assert IDs.ACTIVITIES_TOTAL_AUTO_PCT == "activities-total-auto-pct"
        assert IDs.ACTIVITIES_TOTAL_BASE_DAYS == "activities-total-base-days"
        assert IDs.ACTIVITIES_TOTAL_FINAL_DAYS == "activities-total-final-days"

    def test_component_ids_defined(self):
        """Test that component IDs are defined."""
        assert IDs.COMPONENT_SIMPLE == "component-simple"
        assert IDs.COMPONENT_MEDIUM == "component-medium"
        assert IDs.COMPONENT_COMPLEX == "component-complex"
        assert IDs.COMPONENT_CALCULATOR == "component-calculator"

    def test_timeline_ids_defined(self):
        """Test that timeline IDs are defined."""
        assert IDs.TIMELINE_CONTAINER == "timeline-container"
        assert IDs.TIMELINE_CONTROLS == "timeline-controls"
        assert IDs.TIMELINE_BTN_START == "timeline-btn-start"
        assert IDs.TIMELINE_BTN_BACK == "timeline-btn-back"
        assert IDs.TIMELINE_BTN_PLAY == "timeline-btn-play"
        assert IDs.TIMELINE_BTN_FORWARD == "timeline-btn-forward"
        assert IDs.TIMELINE_BTN_END == "timeline-btn-end"
        assert IDs.TIMELINE_SCRUBBER == "timeline-scrubber"
        assert IDs.TIMELINE_POSITION == "timeline-position"
        assert IDs.TIMELINE_MODE == "timeline-mode"

    def test_effort_ids_defined(self):
        """Test that effort breakdown IDs are defined."""
        assert IDs.EFFORT_BREAKDOWN == "effort-breakdown"
        assert IDs.EFFORT_MANUAL_DAYS == "effort-manual-days"
        assert IDs.EFFORT_AUTOMATION_DAYS == "effort-automation-days"
        assert IDs.EFFORT_TOTAL_DAYS == "effort-total-days"

    def test_buffer_ids_defined(self):
        """Test that buffer IDs are defined."""
        assert IDs.PROPOSED_BUFFERS == "proposed-buffers"
        assert IDs.BUFFER_LEAVE == "buffer-leave"
        assert IDs.BUFFER_DEPENDENCY == "buffer-dependency"
        assert IDs.BUFFER_LEARNING == "buffer-learning"

    def test_team_ids_defined(self):
        """Test that team composition IDs are defined."""
        assert IDs.TEAM_COMPOSITION == "team-composition"
        assert IDs.TEAM_AUTOMATION_COUNT == "team-automation-count"
        assert IDs.TEAM_TESTING_COUNT == "team-testing-count"
        assert IDs.TEAM_TOTAL_COUNT == "team-total-count"


class TestDynamicIDGenerators:
    """Tests for dynamic ID generator methods."""

    def test_activity_row_generator(self):
        """Test activity_row ID generator."""
        assert IDs.activity_row("preprocessing") == "activity-row-preprocessing"
        assert IDs.activity_row("code_conversion") == "activity-row-code_conversion"
        assert IDs.activity_row("post_processing") == "activity-row-post_processing"

    def test_activity_assignment_generator(self):
        """Test activity_assignment ID generator."""
        assert IDs.activity_assignment("preprocessing", "SB") == "activity-preprocessing-assignment-SB"
        assert IDs.activity_assignment("code_conversion", "CG") == "activity-code_conversion-assignment-CG"
        assert IDs.activity_assignment("post_processing", "S2P") == "activity-post_processing-assignment-S2P"

    def test_activity_field_generator(self):
        """Test activity_field ID generator."""
        assert IDs.activity_field("preprocessing", "days") == "activity-preprocessing-days"
        assert IDs.activity_field("preprocessing", "auto-pct") == "activity-preprocessing-auto-pct"
        assert IDs.activity_field("code_conversion", "total-base") == "activity-code_conversion-total-base"

    def test_timeline_event_generator(self):
        """Test timeline_event ID generator."""
        assert IDs.timeline_event(0) == "timeline-event-0"
        assert IDs.timeline_event(1) == "timeline-event-1"
        assert IDs.timeline_event(99) == "timeline-event-99"

    def test_component_calc_field_generator(self):
        """Test component_calc_field ID generator."""
        assert IDs.component_calc_field("simple", "count") == "component-simple-count"
        assert IDs.component_calc_field("medium", "avg-units") == "component-medium-avg-units"
        assert IDs.component_calc_field("complex", "final-days") == "component-complex-final-days"


class TestIDNamingConventions:
    """Tests for ID naming convention consistency."""

    def test_all_ids_are_lowercase_with_dashes(self):
        """Test that all static IDs use lowercase with dashes."""
        static_ids = [
            IDs.NAV_MAIN, IDs.NAV_PROJECT, IDs.NAV_TIMELINE, IDs.NAV_SKILLS,
            IDs.PROJECT_SCOPE, IDs.PROJECT_SCOPE_TOTAL_FILES,
            IDs.ACTIVITIES_TABLE, IDs.ACTIVITIES_TOTALS,
            IDs.COMPONENT_CALCULATOR, IDs.TIMELINE_CONTAINER,
            IDs.EFFORT_BREAKDOWN, IDs.PROPOSED_BUFFERS, IDs.TEAM_COMPOSITION
        ]

        for id_value in static_ids:
            assert id_value == id_value.lower(), f"ID {id_value} should be lowercase"
            assert "_" not in id_value or "-" in id_value, f"ID {id_value} should use dashes"

    def test_dynamic_ids_follow_pattern(self):
        """Test that dynamic IDs follow consistent patterns."""
        # Activity patterns
        activity_row = IDs.activity_row("test")
        assert activity_row.startswith("activity-row-")

        activity_assignment = IDs.activity_assignment("test", "X")
        assert "assignment" in activity_assignment

        # Timeline patterns
        timeline_event = IDs.timeline_event(0)
        assert timeline_event.startswith("timeline-event-")

        # Component patterns
        component_field = IDs.component_calc_field("simple", "count")
        assert component_field.startswith("component-")


class TestIDUniqueness:
    """Tests to ensure IDs are unique."""

    def test_no_duplicate_static_ids(self):
        """Test that all static IDs are unique."""
        all_ids = [
            IDs.NAV_MAIN, IDs.NAV_PROJECT, IDs.NAV_TIMELINE, IDs.NAV_SKILLS,
            IDs.APP_STATUS,
            IDs.PROJECT_SCOPE, IDs.PROJECT_SCOPE_TOTAL_FILES,
            IDs.PROJECT_SCOPE_PROJECT_TYPE, IDs.PROJECT_SCOPE_SIMPLE_COUNT,
            IDs.PROJECT_SCOPE_MEDIUM_COUNT, IDs.PROJECT_SCOPE_COMPLEX_COUNT,
            IDs.COMPONENT_SIMPLE, IDs.COMPONENT_SIMPLE_TOTAL,
            IDs.COMPONENT_MEDIUM, IDs.COMPONENT_MEDIUM_TOTAL,
            IDs.COMPONENT_COMPLEX, IDs.COMPONENT_COMPLEX_TOTAL,
            IDs.ACTIVITIES_TABLE, IDs.ACTIVITIES_TOTALS,
            IDs.ACTIVITIES_TOTAL_AUTO_PCT, IDs.ACTIVITIES_TOTAL_BASE_DAYS,
            IDs.ACTIVITIES_TOTAL_FINAL_DAYS,
            IDs.COMPONENT_CALCULATOR, IDs.COMPONENT_CALC_TOTALS,
            IDs.COMPONENT_TOTALS_TOTAL_UNITS, IDs.COMPONENT_TOTALS_BASE_DAYS,
            IDs.COMPONENT_TOTALS_FINAL_DAYS,
            IDs.PROJECT_DETAILS, IDs.EFFORT_BREAKDOWN,
            IDs.EFFORT_MANUAL_DAYS, IDs.EFFORT_AUTOMATION_DAYS,
            IDs.EFFORT_TOTAL_DAYS,
            IDs.PROPOSED_BUFFERS, IDs.BUFFER_LEAVE, IDs.BUFFER_LEAVE_DAYS,
            IDs.BUFFER_DEPENDENCY, IDs.BUFFER_DEPENDENCY_DAYS,
            IDs.BUFFER_LEARNING, IDs.BUFFER_LEARNING_DAYS,
            IDs.TEAM_COMPOSITION, IDs.TEAM_AUTOMATION_COUNT,
            IDs.TEAM_TESTING_COUNT, IDs.TEAM_TOTAL_COUNT,
            IDs.TIMELINE_CONTAINER, IDs.TIMELINE_CONTROLS,
            IDs.TIMELINE_BTN_START, IDs.TIMELINE_BTN_BACK,
            IDs.TIMELINE_BTN_PLAY, IDs.TIMELINE_BTN_FORWARD,
            IDs.TIMELINE_BTN_END, IDs.TIMELINE_SCRUBBER,
            IDs.TIMELINE_POSITION, IDs.TIMELINE_MODE
        ]

        # Check for duplicates
        seen = set()
        duplicates = []
        for id_value in all_ids:
            if id_value in seen:
                duplicates.append(id_value)
            seen.add(id_value)

        assert len(duplicates) == 0, f"Duplicate IDs found: {duplicates}"


class TestIDDocumentation:
    """Tests for ID documentation completeness."""

    def test_all_sections_have_ids(self):
        """Test that all major sections have corresponding IDs."""
        # Main sections from the UI
        sections = [
            "project-scope",      # Project Scope
            "activities-table",   # Activities Table
            "component-calculator",  # Component Calculator
            "project-details",    # Project Details (parent)
            "effort-breakdown",   # Effort Breakdown
            "proposed-buffers",   # Proposed Buffers
            "team-composition",   # Team Composition
            "timeline-container", # Timeline
        ]

        defined_ids = [
            IDs.PROJECT_SCOPE, IDs.ACTIVITIES_TABLE,
            IDs.COMPONENT_CALCULATOR, IDs.PROJECT_DETAILS,
            IDs.EFFORT_BREAKDOWN, IDs.PROPOSED_BUFFERS,
            IDs.TEAM_COMPOSITION, IDs.TIMELINE_CONTAINER
        ]

        for section in sections:
            assert section in defined_ids, f"Section '{section}' should have a defined ID constant"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
