# NeoExcelPPT Python Playwright Tests

This directory contains Python Playwright tests for the NeoExcelPPT Elixir LiveView application.

## Test Structure

```
test/python/
├── conftest.py      # Pytest configuration and fixtures
├── test_simple.py   # Simple tests (page loads, elements exist)
├── test_medium.py   # Medium tests (interactions, data propagation)
├── run_tests.py     # Test runner script
└── README.md        # This file
```

## Prerequisites

1. **Python 3.8+** with pip
2. **Playwright** and **pytest** packages

Install dependencies:
```bash
pip install playwright pytest pytest-asyncio pytest-playwright
playwright install chromium
```

## Running Tests

### 1. Start the Phoenix Server

First, start the Phoenix server in a separate terminal:

```bash
cd /home/user/neoExcelPPT
mix deps.get
mix phx.server
```

The server will start at http://localhost:4000

### 2. Run Tests

```bash
cd /home/user/neoExcelPPT/test/python

# Run all tests
python run_tests.py

# Run only simple tests
pytest test_simple.py -v

# Run only medium tests
pytest test_medium.py -v

# Run specific test
pytest -k "test_homepage_loads" -v

# Run with visible browser (headed mode)
pytest --headed -v

# Run against different URL
TEST_BASE_URL=http://localhost:4002 pytest -v
```

## Test Categories

### Simple Tests (`test_simple.py`)
- Page loads correctly
- Navigation elements present
- Sections and elements have correct IDs
- Initial values displayed

### Medium Tests (`test_medium.py`)
- File count updates
- Team assignment toggles
- View toggles (show/hide columns)
- Timeline playback controls
- Data propagation between skills
- LiveView reactivity

## HTML Element IDs

All testable elements have consistent IDs defined in `conftest.py`:

### Navigation
- `main-nav` - Main navigation bar
- `nav-project` - Project page link
- `nav-timeline` - Timeline page link
- `nav-skills` - Skills page link

### Project Scope
- `project-scope` - Main container
- `project-scope-total-files` - Total files display
- `project-scope-simple-count` - Simple files input
- `project-scope-medium-count` - Medium files input
- `project-scope-complex-count` - Complex files input

### Activities Table
- `activities-table` - Table container
- `activity-row-{id}` - Activity row (e.g., `activity-row-preprocessing`)
- `activity-{id}-assignment-{member}` - Assignment checkbox
- `activity-{id}-days` - Days per unit
- `activity-{id}-auto-pct` - Automation percentage
- `activity-{id}-total-base` - Base days total
- `activity-{id}-total-final` - Final days total

### Timeline
- `timeline-container` - Main container
- `timeline-controls` - Control buttons container
- `timeline-btn-start` - Go to start
- `timeline-btn-back` - Step backward
- `timeline-btn-play` - Play/pause
- `timeline-btn-forward` - Step forward
- `timeline-btn-end` - Go to end
- `timeline-scrubber` - Position slider
- `timeline-position` - Position display
- `timeline-mode` - Mode indicator (LIVE/REPLAY)
- `timeline-event-{index}` - Event in list

## Adding New Tests

1. Import the IDs from conftest:
   ```python
   from conftest import IDs, BASE_URL
   ```

2. Use the ID constants for element selectors:
   ```python
   def test_my_feature(self, page: Page):
       page.goto(BASE_URL)
       element = page.locator(f"#{IDs.PROJECT_SCOPE}")
       expect(element).to_be_visible()
   ```

3. Use dynamic ID generators for repeated elements:
   ```python
   # For activity rows
   row_id = IDs.activity_row("preprocessing")

   # For assignment checkboxes
   checkbox_id = IDs.activity_assignment("preprocessing", "SB")

   # For timeline events
   event_id = IDs.timeline_event(0)
   ```

## Troubleshooting

### Tests fail with "Page not found"
- Ensure Phoenix server is running at http://localhost:4000
- Check if the correct routes are configured

### Tests timeout
- LiveView needs WebSocket connection - ensure server is running
- Increase timeout: `page.wait_for_timeout(1000)`

### Element not found
- Check if element ID matches the template
- Use browser DevTools to inspect actual IDs
- LiveView may need time to render - add waits

## CI/CD Integration

For CI/CD, you can start the server automatically:

```python
from conftest import PhoenixServer

server = PhoenixServer(port=4002)
server.start()
# Run tests
server.stop()
```

Or use the test configuration in `config/test.exs` which starts the server automatically.
