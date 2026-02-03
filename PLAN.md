# NeoExcelPPT - Elixir LiveView Skills-Actors System

## 3-Second Vision / Goal / Motto

**Vision**: "Living Spreadsheets Powered by Communicating Actors"

**Goal**: Build a reactive project estimation system where each calculation cell is a "Skill" (actor) that communicates changes through channels, enabling real-time collaboration and full audit trail replay.

**Motto**: "Skills Talk, Data Walks"

---

## Architecture Overview

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

---

## Key Choices & Decisions

### 1. **Actor Model Implementation**
- **Choice**: Use Elixir GenServers for Skills (lightweight processes)
- **Why**: Native BEAM concurrency, fault-tolerance, message passing built-in
- **Alternative Rejected**: Using external message queues - overkill for this use case

### 2. **Channel Communication Pattern**
- **Choice**: Phoenix PubSub for inter-skill communication
- **Why**: Built-in, distributed, efficient for real-time updates
- **Pattern**: Each skill subscribes to input channels, publishes to output channels

### 3. **Event Sourcing for Replay**
- **Choice**: In-memory event store with persistence option
- **Why**: Enables forward/backward replay, full audit trail
- **Structure**: `{timestamp, skill_id, channel, old_value, new_value, triggered_by}`

### 4. **Skills as Pure Functions**
- **Choice**: Skills wrap pure functions with side-effect management
- **Why**: Testable, predictable, composable
- **Pattern**: `Skill.compute(inputs) -> outputs` (pure), `Skill.apply(state, inputs) -> new_state` (effectful wrapper)

### 5. **UI Framework**
- **Choice**: Phoenix LiveView with TailwindCSS
- **Why**: Real-time updates without JavaScript complexity, excellent DX
- **Components**: Functional components for reusability

### 6. **State Management**
- **Choice**: ETS tables for fast reads, GenServer for writes
- **Why**: Concurrent reads, serialized writes, survives process crashes

---

## 5-Minute Tasks Breakdown

### Phase 1: Foundation (Tasks 1-4)
| # | Task | Time | Dependencies |
|---|------|------|--------------|
| 1 | Initialize Phoenix project with LiveView | 5 min | None |
| 2 | Configure TailwindCSS and assets | 5 min | Task 1 |
| 3 | Create base Skill behaviour/protocol | 5 min | Task 1 |
| 4 | Implement SkillRegistry GenServer | 5 min | Task 3 |

### Phase 2: Core Actor System (Tasks 5-8)
| # | Task | Time | Dependencies |
|---|------|------|--------------|
| 5 | Create Channel router module | 5 min | Task 4 |
| 6 | Implement EventStore GenServer | 5 min | Task 4 |
| 7 | Build first Skill: TotalFilesSkill | 5 min | Task 5,6 |
| 8 | Build ComponentCalculatorSkill | 5 min | Task 7 |

### Phase 3: LiveView UI (Tasks 9-14)
| # | Task | Time | Dependencies |
|---|------|------|--------------|
| 9 | Create ProjectScopeLive component | 5 min | Task 7,8 |
| 10 | Create ActivitiesTableLive component | 5 min | Task 8 |
| 11 | Create ComponentScalingLive component | 5 min | Task 8 |
| 12 | Create ProjectDetailsLive component | 5 min | Task 9-11 |
| 13 | Create NotificationTimelineLive | 5 min | Task 6 |
| 14 | Wire up real-time updates | 5 min | All above |

### Phase 4: Advanced Features (Tasks 15-18)
| # | Task | Time | Dependencies |
|---|------|------|--------------|
| 15 | Implement replay forward/backward | 5 min | Task 6,13 |
| 16 | Add email notification skill | 5 min | Task 5 |
| 17 | Build skill composition UI | 5 min | Task 14 |
| 18 | Add persistence layer | 5 min | Task 6 |

---

## 30-Minute Plan

### Minute 0-5: Project Bootstrap
```bash
# Initialize Phoenix LiveView project
mix phx.new neo_excel_ppt --live --no-ecto --no-mailer
cd neo_excel_ppt
mix deps.get
```

**Deliverable**: Running Phoenix app at localhost:4000

---

### Minute 5-10: Skills Core Module
Create the foundational Skills behaviour:

```elixir
# lib/neo_excel_ppt/skills/skill.ex
defmodule NeoExcelPPT.Skills.Skill do
  @callback name() :: atom()
  @callback input_channels() :: [atom()]
  @callback output_channels() :: [atom()]
  @callback compute(map()) :: map()
end
```

Create SkillRegistry:
```elixir
# lib/neo_excel_ppt/skills/registry.ex
defmodule NeoExcelPPT.Skills.Registry do
  use GenServer
  # Manages all skill processes, routing, lifecycle
end
```

**Deliverable**: Skill behaviour + Registry GenServer

---

### Minute 10-15: Channel Communication
```elixir
# lib/neo_excel_ppt/skills/channel.ex
defmodule NeoExcelPPT.Skills.Channel do
  # Wraps Phoenix.PubSub for skill communication
  def publish(channel, value)
  def subscribe(channel)
end
```

```elixir
# lib/neo_excel_ppt/skills/event_store.ex
defmodule NeoExcelPPT.Skills.EventStore do
  use GenServer
  # Stores all events for replay
  # {timestamp, skill, channel, old, new, source}
end
```

**Deliverable**: Channel pub/sub + Event store for replay

---

### Minute 15-20: First Skills Implementation
```elixir
# lib/neo_excel_ppt/skills/project_scope_skill.ex
defmodule NeoExcelPPT.Skills.ProjectScopeSkill do
  @behaviour NeoExcelPPT.Skills.Skill

  def input_channels, do: [:simple_files, :medium_files, :complex_files]
  def output_channels, do: [:total_files, :component_breakdown]

  def compute(%{simple: s, medium: m, complex: c}) do
    %{
      total_files: s + m + c,
      simple_components: s * 15,
      medium_components: m * 150,
      complex_components: c * 300
    }
  end
end
```

**Deliverable**: Working ProjectScopeSkill with calculations

---

### Minute 20-25: LiveView Components
```elixir
# lib/neo_excel_ppt_web/live/project_live.ex
defmodule NeoExcelPPTWeb.ProjectLive do
  use NeoExcelPPTWeb, :live_view

  def mount(_params, _session, socket) do
    # Subscribe to skill outputs
    # Initialize state from skills
  end

  def handle_info({:skill_update, channel, value}, socket) do
    # React to skill changes
  end
end
```

**Deliverable**: LiveView page showing Project Scope

---

### Minute 25-30: Activities Table + Wiring
```elixir
# lib/neo_excel_ppt_web/live/components/activities_table.ex
defmodule NeoExcelPPTWeb.Components.ActivitiesTable do
  use Phoenix.Component

  # Render activities with team assignments
  # Connect to Activity skills
end
```

```elixir
# lib/neo_excel_ppt_web/live/components/notification_timeline.ex
defmodule NeoExcelPPTWeb.Components.NotificationTimeline do
  # Shows event history
  # Play forward/backward controls
end
```

**Deliverable**: Full page layout with live-updating components

---

## Skill Definitions for Project Estimation

### Core Skills (Actors)

| Skill Name | Input Channels | Output Channels | Pure Function |
|------------|----------------|-----------------|---------------|
| `ProjectScope` | `:file_counts` | `:total_files`, `:components` | Sum files, multiply by complexity |
| `ActivityCalculator` | `:days_unit`, `:auto_pct` | `:base_days`, `:final_days` | base * (1 - auto_pct) |
| `TeamAssignment` | `:activity`, `:member` | `:assignment_changed` | Toggle assignment |
| `ComponentScaler` | `:count`, `:avg_units`, `:time_unit` | `:total_units`, `:base_days` | count * avg * time |
| `EffortAggregator` | `:all_activities` | `:manual_days`, `:auto_days`, `:total` | Sum all activity days |
| `BufferCalculator` | `:total_effort`, `:buffer_pct` | `:buffer_days` | effort * buffer_pct |
| `NotificationSkill` | `:any_change` | `:email_queue` | Format and queue notification |

### Skill Communication Flow Example
```
User changes "Simple Files" count
    │
    ▼
[ProjectScope Skill] receives :file_counts
    │
    ├──► publishes :total_files (55000)
    │        │
    │        ▼
    │    [EffortAggregator] recalculates totals
    │
    └──► publishes :simple_components (825k)
             │
             ▼
         [ComponentScaler] recalculates
             │
             ▼
         [NotificationSkill] queues change notification
             │
             ▼
         [EventStore] records all events with timestamps
```

---

## File Structure

```
lib/
├── neo_excel_ppt/
│   ├── application.ex
│   └── skills/
│       ├── skill.ex              # Behaviour definition
│       ├── registry.ex           # GenServer managing skills
│       ├── channel.ex            # PubSub wrapper
│       ├── event_store.ex        # Event sourcing store
│       ├── project_scope.ex      # Skill implementation
│       ├── activity_calc.ex      # Skill implementation
│       ├── component_scaler.ex   # Skill implementation
│       ├── effort_aggregator.ex  # Skill implementation
│       └── notification.ex       # Skill implementation
│
├── neo_excel_ppt_web/
│   ├── router.ex
│   └── live/
│       ├── project_live.ex       # Main page LiveView
│       └── components/
│           ├── project_scope.ex
│           ├── activities_table.ex
│           ├── component_scaling.ex
│           ├── project_details.ex
│           └── notification_timeline.ex
│
└── assets/
    └── css/
        └── app.css               # TailwindCSS styles
```

---

## Success Criteria

1. **Skills communicate via channels** - Change in one skill propagates to dependent skills
2. **Full event replay** - Can step through history forward and backward
3. **Real-time UI updates** - LiveView reflects skill changes instantly
4. **Pure function core** - All calculations testable without actors
5. **Visual match** - UI matches the provided screenshots

---

## Next Steps After 30 Minutes

1. Add database persistence for projects
2. Implement email notifications
3. Add user authentication
4. Build skill composition editor
5. Export to Excel/PDF
6. Add collaborative editing (multiple users)
