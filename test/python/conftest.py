"""
Pytest configuration for NeoExcelPPT Playwright tests.

This module provides fixtures and configuration for testing the
Elixir LiveView application using Playwright.
"""

import pytest
from playwright.sync_api import Page, Browser, BrowserContext
import subprocess
import time
import os
import signal

# Default base URL for the Phoenix server
BASE_URL = os.environ.get("TEST_BASE_URL", "http://localhost:4000")


@pytest.fixture(scope="session")
def base_url():
    """Return the base URL for the Phoenix server."""
    return BASE_URL


@pytest.fixture(scope="function")
def page_with_url(page: Page, base_url: str):
    """Navigate to the base URL before each test."""
    page.goto(base_url)
    # Wait for LiveView to connect
    page.wait_for_selector("[data-phx-main]", timeout=10000)
    return page


class PhoenixServer:
    """
    Helper class to manage the Phoenix server for testing.

    Note: In most cases, you'll want to start the server manually before
    running tests. This class is provided for convenience in CI/CD environments.
    """

    def __init__(self, port: int = 4000):
        self.port = port
        self.process = None

    def start(self):
        """Start the Phoenix server."""
        env = os.environ.copy()
        env["MIX_ENV"] = "test"
        env["PORT"] = str(self.port)

        self.process = subprocess.Popen(
            ["mix", "phx.server"],
            cwd="/home/user/neoExcelPPT",
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            preexec_fn=os.setsid
        )

        # Wait for server to be ready
        max_retries = 30
        for i in range(max_retries):
            try:
                import urllib.request
                urllib.request.urlopen(f"http://localhost:{self.port}")
                return True
            except:
                time.sleep(1)

        raise RuntimeError("Phoenix server failed to start")

    def stop(self):
        """Stop the Phoenix server."""
        if self.process:
            os.killpg(os.getpgid(self.process.pid), signal.SIGTERM)
            self.process = None


# Element ID constants for easy reference in tests
class ElementIDs:
    """
    Constants for HTML element IDs used in tests.

    All elements in the LiveView app follow a consistent naming convention:
    - section-name: Main section containers
    - section-name-field: Specific fields within sections
    - skill-name-input-field: Skill input fields
    - skill-name-output-field: Skill output displays
    """

    # Navigation
    NAV_MAIN = "main-nav"
    NAV_PROJECT = "nav-project"
    NAV_TIMELINE = "nav-timeline"
    NAV_SKILLS = "nav-skills"
    APP_STATUS = "app-status"

    # Project Scope Section
    PROJECT_SCOPE = "project-scope"
    PROJECT_SCOPE_TOTAL_FILES = "project-scope-total-files"
    PROJECT_SCOPE_PROJECT_TYPE = "project-scope-project-type"
    PROJECT_SCOPE_SIMPLE_COUNT = "project-scope-simple-count"
    PROJECT_SCOPE_MEDIUM_COUNT = "project-scope-medium-count"
    PROJECT_SCOPE_COMPLEX_COUNT = "project-scope-complex-count"

    # Component Breakdown
    COMPONENT_SIMPLE = "component-simple"
    COMPONENT_SIMPLE_TOTAL = "component-simple-total"
    COMPONENT_MEDIUM = "component-medium"
    COMPONENT_MEDIUM_TOTAL = "component-medium-total"
    COMPONENT_COMPLEX = "component-complex"
    COMPONENT_COMPLEX_TOTAL = "component-complex-total"

    # Activities Table
    ACTIVITIES_TABLE = "activities-table"
    ACTIVITIES_TOTALS = "activities-totals"
    ACTIVITIES_TOTAL_AUTO_PCT = "activities-total-auto-pct"
    ACTIVITIES_TOTAL_BASE_DAYS = "activities-total-base-days"
    ACTIVITIES_TOTAL_FINAL_DAYS = "activities-total-final-days"

    # Component Calculator
    COMPONENT_CALCULATOR = "component-calculator"
    COMPONENT_CALC_TOTALS = "component-calc-totals"
    COMPONENT_TOTALS_TOTAL_UNITS = "component-totals-total-units"
    COMPONENT_TOTALS_BASE_DAYS = "component-totals-base-days"
    COMPONENT_TOTALS_FINAL_DAYS = "component-totals-final-days"

    # Project Details
    PROJECT_DETAILS = "project-details"
    EFFORT_BREAKDOWN = "effort-breakdown"
    EFFORT_MANUAL_DAYS = "effort-manual-days"
    EFFORT_AUTOMATION_DAYS = "effort-automation-days"
    EFFORT_TOTAL_DAYS = "effort-total-days"

    # Proposed Buffers
    PROPOSED_BUFFERS = "proposed-buffers"
    BUFFER_LEAVE = "buffer-leave"
    BUFFER_LEAVE_DAYS = "buffer-leave-days"
    BUFFER_DEPENDENCY = "buffer-dependency"
    BUFFER_DEPENDENCY_DAYS = "buffer-dependency-days"
    BUFFER_LEARNING = "buffer-learning"
    BUFFER_LEARNING_DAYS = "buffer-learning-days"

    # Team Composition
    TEAM_COMPOSITION = "team-composition"
    TEAM_AUTOMATION_COUNT = "team-automation-count"
    TEAM_TESTING_COUNT = "team-testing-count"
    TEAM_TOTAL_COUNT = "team-total-count"

    # Timeline
    TIMELINE_CONTAINER = "timeline-container"
    TIMELINE_CONTROLS = "timeline-controls"
    TIMELINE_BTN_START = "timeline-btn-start"
    TIMELINE_BTN_BACK = "timeline-btn-back"
    TIMELINE_BTN_PLAY = "timeline-btn-play"
    TIMELINE_BTN_FORWARD = "timeline-btn-forward"
    TIMELINE_BTN_END = "timeline-btn-end"
    TIMELINE_SCRUBBER = "timeline-scrubber"
    TIMELINE_POSITION = "timeline-position"
    TIMELINE_MODE = "timeline-mode"

    @staticmethod
    def activity_row(activity_id: str) -> str:
        """Generate ID for an activity row."""
        return f"activity-row-{activity_id}"

    @staticmethod
    def activity_assignment(activity_id: str, member: str) -> str:
        """Generate ID for an activity team assignment checkbox."""
        return f"activity-{activity_id}-assignment-{member}"

    @staticmethod
    def activity_field(activity_id: str, field: str) -> str:
        """Generate ID for an activity field."""
        return f"activity-{activity_id}-{field}"

    @staticmethod
    def timeline_event(index: int) -> str:
        """Generate ID for a timeline event."""
        return f"timeline-event-{index}"

    @staticmethod
    def component_calc_field(comp_type: str, field: str) -> str:
        """Generate ID for a component calculator field."""
        return f"component-{comp_type}-{field}"


# Export for easy importing in tests
IDs = ElementIDs
