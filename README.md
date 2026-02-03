# NeoExcelPPT - Skills-Actors Project Estimation System

A reactive project estimation system built with Elixir, Phoenix LiveView, and an actor-based "Skills" architecture.

## Vision

**"Living Spreadsheets Powered by Communicating Actors"**

Each calculation cell is a "Skill" (actor) that communicates changes through channels, enabling real-time collaboration and full audit trail replay.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        LiveView UI Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                 │
│  │ ProjectScope│  │ Activities  │  │  Calculator │                 │
│  │  Component  │  │  Component  │  │  Component  │                 │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                 │
└─────────┼────────────────┼────────────────┼─────────────────────────┘
          │                │                │
          ▼                ▼                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Skills Registry (GenServer)                       │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Channel Router - Routes messages between skills              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐               │
│  │ Skill A │◄─►│ Skill B │◄─►│ Skill C │◄─►│ Skill D │               │
│  │ (Actor) │  │ (Actor) │  │ (Actor) │  │ (Actor) │               │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘               │
└─────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Event Store (Event Sourcing)                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Timeline: [Event1] → [Event2] → [Event3] → [Event4]         │  │
│  │            ◄─── Replay Backward    Forward Replay ───►       │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

## Key Concepts

### Skills as Actors
- Each Skill is an Elixir GenServer (actor)
- Skills are pure functions with input/output channel names
- Skills communicate through Phoenix PubSub channels
- Changes trigger notifications and can cascade through the skill graph

### Event Sourcing
- All skill state changes are recorded as events
- Events can be replayed forward or backward
- Full audit trail of all changes
- Time-travel debugging capability

### Real-time Updates
- Phoenix LiveView provides real-time UI updates
- No JavaScript required for reactivity
- Changes propagate instantly across all connected clients

## Features

- **Project Scope** - Track files, components, and complexity
- **Activities Table** - Manage tasks with team assignments
- **Component Scaling Calculator** - Calculate effort based on component counts
- **Effort Breakdown** - View manual vs automation days
- **Buffer Calculator** - Plan for leaves, dependencies, and learning curves
- **Team Composition** - Resource planning

## Skills Included

| Skill | Description | Input Channels | Output Channels |
|-------|-------------|----------------|-----------------|
| `ProjectScopeSkill` | Calculates project metrics | file counts | total files, components |
| `ComponentScalerSkill` | Scales effort calculations | component counts | base days, final days |
| `ActivityCalculatorSkill` | Calculates activity effort | activity updates | activities summary |
| `EffortAggregatorSkill` | Aggregates total effort | day totals | effort breakdown |
| `BufferCalculatorSkill` | Calculates project buffers | final days | buffer days |

## Getting Started

### Prerequisites
- Elixir 1.14+
- Phoenix 1.7+
- Node.js 18+ (for assets)

### Installation

```bash
# Clone the repository
git clone https://github.com/your-repo/neoExcelPPT.git
cd neoExcelPPT

# Install dependencies
mix deps.get

# Install Node.js dependencies for assets
cd assets && npm install && cd ..

# Start the Phoenix server
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000) to see the application.

### Running in Development

```bash
# Start with interactive shell
iex -S mix phx.server

# Run tests
mix test

# Format code
mix format
```

## Project Structure

```
lib/
├── neo_excel_ppt/
│   ├── application.ex          # Application supervisor
│   └── skills/
│       ├── skill.ex            # Skill behaviour
│       ├── registry.ex         # Skills supervisor
│       ├── channel.ex          # PubSub wrapper
│       ├── event_store.ex      # Event sourcing
│       └── *_skill.ex          # Skill implementations
│
├── neo_excel_ppt_web/
│   ├── router.ex               # Routes
│   ├── endpoint.ex             # HTTP endpoint
│   └── live/
│       ├── project_live.ex     # Main dashboard
│       ├── skills_live.ex      # Skills management
│       └── timeline_live.ex    # Event replay
│
└── assets/
    ├── css/app.css             # TailwindCSS styles
    └── js/app.js               # Phoenix LiveView JS
```

## Creating a Custom Skill

```elixir
defmodule NeoExcelPPT.Skills.MyCustomSkill do
  use NeoExcelPPT.Skills.Skill

  @impl true
  def name, do: :my_custom_skill

  @impl true
  def input_channels, do: [:input_a, :input_b]

  @impl true
  def output_channels, do: [:result]

  @impl true
  def compute(%{input_a: a, input_b: b}) do
    %{result: a + b}
  end
end
```

## API

### Channel Communication

```elixir
# Subscribe to a channel
Channel.subscribe(:total_files)

# Publish to a channel
Channel.publish(:total_files, 55000)
```

### Event Store

```elixir
# Get all events
EventStore.get_events()

# Step through history
EventStore.step_forward()
EventStore.step_backward()

# Replay to a specific point
EventStore.replay_to_index(5)
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see LICENSE file for details
