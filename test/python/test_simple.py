"""
Simple Tests for NeoExcelPPT LiveView Application.

These tests verify basic functionality:
- Page loads correctly
- Elements are present with correct IDs
- Basic navigation works
- Initial values are displayed
"""

import pytest
from playwright.sync_api import Page, expect
from conftest import IDs, BASE_URL


class TestPageLoad:
    """Tests for basic page loading and structure."""

    def test_homepage_loads(self, page: Page):
        """Test that the homepage loads successfully."""
        page.goto(BASE_URL)
        expect(page).to_have_title("Project Estimation · NeoExcelPPT")

    def test_navigation_is_present(self, page: Page):
        """Test that navigation elements are present."""
        page.goto(BASE_URL)

        # Check main nav exists
        nav = page.locator(f"#{IDs.NAV_MAIN}")
        expect(nav).to_be_visible()

        # Check nav links
        expect(page.locator(f"#{IDs.NAV_PROJECT}")).to_be_visible()
        expect(page.locator(f"#{IDs.NAV_TIMELINE}")).to_be_visible()
        expect(page.locator(f"#{IDs.NAV_SKILLS}")).to_be_visible()

    def test_app_status_shows_active(self, page: Page):
        """Test that the app status indicator shows skills are active."""
        page.goto(BASE_URL)

        status = page.locator(f"#{IDs.APP_STATUS}")
        expect(status).to_be_visible()
        expect(status).to_contain_text("Active")


class TestProjectScopeSection:
    """Tests for the Project Scope section."""

    def test_project_scope_section_exists(self, page: Page):
        """Test that the project scope section is present."""
        page.goto(BASE_URL)

        section = page.locator(f"#{IDs.PROJECT_SCOPE}")
        expect(section).to_be_visible()

    def test_total_files_displayed(self, page: Page):
        """Test that total files count is displayed."""
        page.goto(BASE_URL)

        total_files = page.locator(f"#{IDs.PROJECT_SCOPE_TOTAL_FILES}")
        expect(total_files).to_be_visible()
        # Should contain a number
        expect(total_files).to_have_text(lambda text: any(c.isdigit() for c in text))

    def test_project_type_displayed(self, page: Page):
        """Test that project type badge is displayed."""
        page.goto(BASE_URL)

        project_type = page.locator(f"#{IDs.PROJECT_SCOPE_PROJECT_TYPE}")
        expect(project_type).to_be_visible()
        expect(project_type).to_contain_text("ODI")

    def test_file_count_inputs_exist(self, page: Page):
        """Test that file count input fields exist."""
        page.goto(BASE_URL)

        # Simple files input
        simple = page.locator(f"#{IDs.PROJECT_SCOPE_SIMPLE_COUNT}")
        expect(simple).to_be_visible()
        expect(simple).to_have_attribute("type", "number")

        # Medium files input
        medium = page.locator(f"#{IDs.PROJECT_SCOPE_MEDIUM_COUNT}")
        expect(medium).to_be_visible()

        # Complex files input
        complex_input = page.locator(f"#{IDs.PROJECT_SCOPE_COMPLEX_COUNT}")
        expect(complex_input).to_be_visible()

    def test_component_breakdown_displayed(self, page: Page):
        """Test that component breakdown is displayed."""
        page.goto(BASE_URL)

        # Check each component type card
        expect(page.locator(f"#{IDs.COMPONENT_SIMPLE}")).to_be_visible()
        expect(page.locator(f"#{IDs.COMPONENT_MEDIUM}")).to_be_visible()
        expect(page.locator(f"#{IDs.COMPONENT_COMPLEX}")).to_be_visible()

        # Check totals are displayed
        expect(page.locator(f"#{IDs.COMPONENT_SIMPLE_TOTAL}")).to_be_visible()
        expect(page.locator(f"#{IDs.COMPONENT_MEDIUM_TOTAL}")).to_be_visible()
        expect(page.locator(f"#{IDs.COMPONENT_COMPLEX_TOTAL}")).to_be_visible()


class TestActivitiesTable:
    """Tests for the Activities table section."""

    def test_activities_table_exists(self, page: Page):
        """Test that the activities table is present."""
        page.goto(BASE_URL)

        table = page.locator(f"#{IDs.ACTIVITIES_TABLE}")
        expect(table).to_be_visible()

    def test_activities_totals_row_exists(self, page: Page):
        """Test that the totals row is present."""
        page.goto(BASE_URL)

        totals = page.locator(f"#{IDs.ACTIVITIES_TOTALS}")
        expect(totals).to_be_visible()

    def test_activity_rows_have_correct_ids(self, page: Page):
        """Test that activity rows have proper IDs for testing."""
        page.goto(BASE_URL)

        # Check for known activity rows
        activities = ["preprocessing", "code_conversion", "execution_with_data", "post_processing"]

        for activity in activities:
            row = page.locator(f"#{IDs.activity_row(activity)}")
            expect(row).to_be_visible()


class TestComponentCalculator:
    """Tests for the Component Calculator section."""

    def test_calculator_section_exists(self, page: Page):
        """Test that the component calculator section exists."""
        page.goto(BASE_URL)

        calc = page.locator(f"#{IDs.COMPONENT_CALCULATOR}")
        expect(calc).to_be_visible()

    def test_calculator_totals_displayed(self, page: Page):
        """Test that calculator totals are displayed."""
        page.goto(BASE_URL)

        totals = page.locator(f"#{IDs.COMPONENT_CALC_TOTALS}")
        expect(totals).to_be_visible()


class TestProjectDetails:
    """Tests for the Project Details section."""

    def test_effort_breakdown_exists(self, page: Page):
        """Test that effort breakdown section exists."""
        page.goto(BASE_URL)

        effort = page.locator(f"#{IDs.EFFORT_BREAKDOWN}")
        expect(effort).to_be_visible()

    def test_effort_values_displayed(self, page: Page):
        """Test that effort values are displayed."""
        page.goto(BASE_URL)

        expect(page.locator(f"#{IDs.EFFORT_MANUAL_DAYS}")).to_be_visible()
        expect(page.locator(f"#{IDs.EFFORT_AUTOMATION_DAYS}")).to_be_visible()
        expect(page.locator(f"#{IDs.EFFORT_TOTAL_DAYS}")).to_be_visible()

    def test_buffers_section_exists(self, page: Page):
        """Test that proposed buffers section exists."""
        page.goto(BASE_URL)

        buffers = page.locator(f"#{IDs.PROPOSED_BUFFERS}")
        expect(buffers).to_be_visible()

    def test_buffer_rows_displayed(self, page: Page):
        """Test that buffer rows are displayed."""
        page.goto(BASE_URL)

        expect(page.locator(f"#{IDs.BUFFER_LEAVE}")).to_be_visible()
        expect(page.locator(f"#{IDs.BUFFER_DEPENDENCY}")).to_be_visible()
        expect(page.locator(f"#{IDs.BUFFER_LEARNING}")).to_be_visible()

    def test_team_composition_exists(self, page: Page):
        """Test that team composition section exists."""
        page.goto(BASE_URL)

        team = page.locator(f"#{IDs.TEAM_COMPOSITION}")
        expect(team).to_be_visible()

    def test_team_counts_displayed(self, page: Page):
        """Test that team counts are displayed."""
        page.goto(BASE_URL)

        expect(page.locator(f"#{IDs.TEAM_AUTOMATION_COUNT}")).to_be_visible()
        expect(page.locator(f"#{IDs.TEAM_TESTING_COUNT}")).to_be_visible()
        expect(page.locator(f"#{IDs.TEAM_TOTAL_COUNT}")).to_be_visible()


class TestNavigation:
    """Tests for page navigation."""

    def test_navigate_to_timeline(self, page: Page):
        """Test navigation to timeline page."""
        page.goto(BASE_URL)

        # Click timeline nav link
        page.click(f"#{IDs.NAV_TIMELINE}")

        # Should be on timeline page
        expect(page).to_have_url(f"{BASE_URL}/timeline")
        expect(page.locator(f"#{IDs.TIMELINE_CONTAINER}")).to_be_visible()

    def test_navigate_to_skills(self, page: Page):
        """Test navigation to skills page."""
        page.goto(BASE_URL)

        # Click skills nav link
        page.click(f"#{IDs.NAV_SKILLS}")

        # Should be on skills page
        expect(page).to_have_url(f"{BASE_URL}/skills")

    def test_navigate_back_to_project(self, page: Page):
        """Test navigation back to project page."""
        page.goto(f"{BASE_URL}/timeline")

        # Click project nav link
        page.click(f"#{IDs.NAV_PROJECT}")

        # Should be back on project page
        expect(page).to_have_url(BASE_URL + "/")
        expect(page.locator(f"#{IDs.PROJECT_SCOPE}")).to_be_visible()


class TestTimelinePageSimple:
    """Simple tests for the Timeline page."""

    def test_timeline_page_loads(self, page: Page):
        """Test that timeline page loads."""
        page.goto(f"{BASE_URL}/timeline")

        expect(page.locator(f"#{IDs.TIMELINE_CONTAINER}")).to_be_visible()

    def test_timeline_controls_exist(self, page: Page):
        """Test that timeline control buttons exist."""
        page.goto(f"{BASE_URL}/timeline")

        expect(page.locator(f"#{IDs.TIMELINE_CONTROLS}")).to_be_visible()
        expect(page.locator(f"#{IDs.TIMELINE_BTN_START}")).to_be_visible()
        expect(page.locator(f"#{IDs.TIMELINE_BTN_BACK}")).to_be_visible()
        expect(page.locator(f"#{IDs.TIMELINE_BTN_PLAY}")).to_be_visible()
        expect(page.locator(f"#{IDs.TIMELINE_BTN_FORWARD}")).to_be_visible()
        expect(page.locator(f"#{IDs.TIMELINE_BTN_END}")).to_be_visible()

    def test_timeline_scrubber_exists(self, page: Page):
        """Test that timeline scrubber exists."""
        page.goto(f"{BASE_URL}/timeline")

        scrubber = page.locator(f"#{IDs.TIMELINE_SCRUBBER}")
        expect(scrubber).to_be_visible()
        expect(scrubber).to_have_attribute("type", "range")

    def test_timeline_mode_indicator_exists(self, page: Page):
        """Test that timeline mode indicator exists."""
        page.goto(f"{BASE_URL}/timeline")

        mode = page.locator(f"#{IDs.TIMELINE_MODE}")
        expect(mode).to_be_visible()
