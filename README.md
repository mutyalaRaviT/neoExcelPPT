# NeoExcelPPT - Skills-Actors Project Estimation System

A reactive project estimation system built with Elixir, Phoenix LiveView, and an actor-based "Skills" architecture.

## 3-Second Vision

**"Autonomous UI: Interface as an Event Stream"**

Each UI component is an autonomous Actor (Skill) that communicates through channels. The interface is a living reflection of the message bus, with full time-travel capability.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LIVEVIEW PARENT                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    SKILL MANAGER (Orchestrator)                      │   │
│  │  wiring: %{                                                          │   │
│  │    "project_scope:output" => ["component_calc:input"],               │   │
│  │    "component_calc:output" => ["effort:input"]                       │   │
│  │  }                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│         ┌──────────────────────────┼──────────────────────────┐             │
│         ▼                          ▼                          ▼             │
│  ┌─────────────┐           ┌─────────────┐           ┌─────────────┐       │
│  │ SKILL:      │           │ SKILL:      │           │ SKILL:      │       │
│  │ project     │──output──▶│ component   │──output──▶│ effort      │       │
│  │ _scope      │           │ _calculator │           │ _aggregator │       │
│  │             │           │             │           │             │       │
│  │ Pure Fn:    │           │ Pure Fn:    │           │ Pure Fn:    │       │
│  │ count files │           │ files × 15  │           │ sum days    │       │
│  └─────────────┘           └─────────────┘           └─────────────┘       │
│         │                          │                          │             │
│         └──────────────────────────┼──────────────────────────┘             │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    HISTORY TRACKER (The Tape)                        │   │
│  │  events: [                                                           │   │
│  │    {t1, :project_scope, :total_files, 55000},                       │   │
│  │    {t2, :component_calc, :scaled_effort, 825000},                   │   │
│  │    {t3, :effort_aggregator, :total_days, 82.5}                      │   │
│  │  ]                                                                   │   │
│  │  position: 3 | mode: :live                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │              NOTIFICATION UI (Time-Travel Controls)                  │   │
│  │  [⏮️ Start] [⏪ Back] [▶️ Play] [⏩ Forward] [⏭️ End]                │   │
│  │  ════════════════════●═══════════════════════════                   │   │
│  │  Event 3/10: component_calc changed 825000 → 840000                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key Concepts

### Skills as Actors
- Each Skill is an Elixir GenServer (actor process)
- Skills wrap **pure functions**: `compute(state, input) -> {new_state, outputs}`
- Skills communicate through Phoenix PubSub channels
- Changes cascade through the skill dependency graph

### The Tape (History Tracker)
- All skill state changes are recorded as events
- Events can be replayed forward or backward (time-travel)
- Full audit trail of all changes
- Enables debugging by stepping through history

### Real-time Updates
- Phoenix LiveView provides real-time UI updates
- Changes propagate instantly across all connected clients
- No page refresh required

## Features

| Feature | Description |
|---------|-------------|
| **Project Scope** | Track files (simple/medium/complex) and component breakdown |
| **Activities Table** | Manage tasks with team assignments (SB, CG, S2P) |
| **Component Calculator** | Calculate effort based on component counts and automation % |
| **Effort Breakdown** | View manual vs automation days |
| **Buffer Calculator** | Plan for leaves, dependencies, and learning curves |
| **Team Composition** | Resource planning and allocation |
| **Timeline** | Time-travel through skill communications |

## Skills Included

| Skill | Pure Function | Input Channels | Output Channels |
|-------|---------------|----------------|-----------------|
| `ProjectScopeSkill` | Count files → components | `:file_counts` | `:total_files`, `:component_breakdown` |
| `ComponentCalculatorSkill` | Components × time → days | `:breakdown` | `:scaled_effort` |
| `ActivityCalculatorSkill` | Activities → totals | `:activity_update`, `:team_assignment` | `:activity_totals` |
| `EffortAggregatorSkill` | Sum all effort sources | `:component_effort`, `:activity_effort` | `:total_days` |
| `BufferCalculatorSkill` | Base days × buffer % | `:base_days` | `:buffer_days` |

## Getting Started

### Prerequisites

- **Elixir** 1.14+ with Erlang/OTP 25+
- **Node.js** 18+ (for assets)
- **Python** 3.8+ (for tests)

### Installation

```bash
# Clone the repository
git clone https://github.com/mutyalaRaviT/neoExcelPPT.git
cd neoExcelPPT

# Install Elixir dependencies
mix deps.get

# Install Node.js dependencies
cd assets && npm install && cd ..

# Start the Phoenix server
mix phx.server
```

Visit [localhost:4000](http://localhost:4000) to see the application.

### Pages

| Route | Description |
|-------|-------------|
| `/` | Main project estimation dashboard |
| `/timeline` | Event history with time-travel controls |
| `/skills` | Skills registry and communication graph |

## Project Structure

```
lib/
├── neo_excel_ppt/
│   ├── application.ex              # Application supervisor
│   └── skills/
│       ├── skill.ex                # Skill behaviour (pure function wrapper)
│       ├── skill_manager.ex        # Communication orchestrator
│       ├── history_tracker.ex      # The Tape (event sourcing)
│       ├── channel.ex              # PubSub wrapper
│       ├── registry.ex             # Process registry
│       ├── project_scope_skill.ex
│       ├── component_calculator_skill.ex
│       ├── activity_calculator_skill.ex
│       ├── effort_aggregator_skill.ex
│       └── buffer_calculator_skill.ex
│
├── neo_excel_ppt_web/
│   ├── router.ex
│   ├── endpoint.ex
│   ├── components/
│   │   ├── core_components.ex      # Reusable UI components
│   │   └── layouts/
│   └── live/
│       ├── project_live.ex         # Main dashboard
│       ├── timeline_live.ex        # Time-travel UI
│       └── skills_live.ex          # Skills management
│
├── assets/
│   ├── css/app.css                 # TailwindCSS styles
│   └── js/app.js                   # LiveView hooks
│
└── test/
    └── python/                     # Playwright tests
        ├── conftest.py             # Test configuration & IDs
        ├── test_unit.py            # Unit tests (no browser)
        ├── test_simple.py          # Basic UI tests
        └── test_medium.py          # Interaction tests
```

## Creating a Custom Skill

```elixir
defmodule NeoExcelPPT.Skills.MyCustomSkill do
  use NeoExcelPPT.Skills.Skill

  @impl true
  def skill_id, do: :my_custom_skill

  @impl true
  def input_channels, do: [:input_a, :input_b]

  @impl true
  def output_channels, do: [:result]

  @impl true
  def initial_state, do: %{value: 0}

  @impl true
  def compute(state, input) do
    # Pure function: (state, input) -> {new_state, outputs}
    new_value = state.value + input.data
    new_state = %{state | value: new_value}
    outputs = %{result: new_value}
    {new_state, outputs}
  end
end
```

## API

### Channel Communication

```elixir
alias NeoExcelPPT.Skills.Channel

# Subscribe to a channel
Channel.subscribe(:total_files)

# Broadcast to a channel
Channel.broadcast(:total_files, %{from: :my_skill, data: 55000})
```

### History Tracker (Time-Travel)

```elixir
alias NeoExcelPPT.Skills.HistoryTracker

# Get all events
HistoryTracker.get_events()

# Get current position
HistoryTracker.get_position()
# => %{position: 5, total: 10, mode: :live}

# Step through history
HistoryTracker.step_forward()
HistoryTracker.step_backward()

# Jump to specific position
HistoryTracker.goto_index(3)

# Go to start/end
HistoryTracker.goto_start()
HistoryTracker.goto_end()  # Returns to :live mode
```

### Skill Manager

```elixir
alias NeoExcelPPT.Skills.SkillManager

# Get all skills
SkillManager.get_skills()

# Get dependency graph
SkillManager.get_dependency_graph()

# Send input to a skill
SkillManager.send_input(:project_scope, :file_counts, %{simple: 60000})
```

## Testing

### Python Playwright Tests

The project includes comprehensive Python tests using Playwright.

```bash
# Install test dependencies
pip install playwright pytest pytest-playwright
playwright install chromium

# Run unit tests (no browser required)
cd test/python
python -m pytest test_unit.py -v

# Run all tests (requires Phoenix server running)
mix phx.server  # In another terminal
python -m pytest -v
```

### Test Results

```
test_unit.py - 19 tests (Configuration, Element IDs, Naming Conventions)
test_simple.py - 26 tests (Page loads, Elements exist, Navigation)
test_medium.py - 20+ tests (Interactions, Data propagation, LiveView)
```

### HTML Element IDs for Testing

All testable elements have consistent IDs defined in `test/python/conftest.py`:

#### Navigation
- `main-nav`, `nav-project`, `nav-timeline`, `nav-skills`

#### Project Scope
- `project-scope`, `project-scope-total-files`, `project-scope-project-type`
- `project-scope-simple-count`, `project-scope-medium-count`, `project-scope-complex-count`
- `component-simple`, `component-medium`, `component-complex`

#### Activities Table
- `activities-table`, `activities-totals`
- `activity-row-{id}` (e.g., `activity-row-preprocessing`)
- `activity-{id}-assignment-{member}` (e.g., `activity-preprocessing-assignment-SB`)
- `activity-{id}-days`, `activity-{id}-auto-pct`, `activity-{id}-total-base`

#### Component Calculator
- `component-calculator`, `component-calc-totals`
- `component-{type}-count`, `component-{type}-final-days`

#### Project Details
- `effort-breakdown`, `effort-manual-days`, `effort-automation-days`
- `proposed-buffers`, `buffer-leave`, `buffer-dependency`, `buffer-learning`
- `team-composition`, `team-automation-count`, `team-testing-count`

#### Timeline
- `timeline-container`, `timeline-controls`
- `timeline-btn-start`, `timeline-btn-back`, `timeline-btn-play`, `timeline-btn-forward`, `timeline-btn-end`
- `timeline-scrubber`, `timeline-position`, `timeline-mode`
- `timeline-event-{index}`

## Development

```bash
# Start with interactive shell
iex -S mix phx.server

# Run Elixir tests
mix test

# Format code
mix format

# Check for issues
mix credo
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see LICENSE file for details

---

**Motto:** *"Skills Talk, Data Walks"*
