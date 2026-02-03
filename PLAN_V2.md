# NeoExcelPPT - Plan V2: Autonomous UI as Event Stream

This approach treats UI components as autonomous **Actors** (Skills), where the interface is a living reflection of the message bus. By making every Skill a pure function with input/output channels, you're essentially building a **reactive, auditable state machine** where the "Notification" log becomes the single source of truth for time-travel (forward/backward playback).

## 3s Vision

**"Autonomous UI: Interface as an Event Stream."**

---

## 5min Tasks & Key Choices

### Key Choices

* **Skill Registry:** Use Elixir's `Registry` or `Phoenix.PubSub` to map input/output channel names to specific PID/Skill instances.
* **The "Tape" (Notification Log):** Store all inter-skill messages in a central `GenServer` or `ETS` table to allow for the "Play Forward/Backward" feature.
* **Pure Function Core:** Each Skill wraps a pure function: `(state, input) -> (new_state, output)`.

### 5min Tasks

1. **Define the Skill Behavior:** Create a module template that requires `render/1`, `handle_input/2`, and `output_channels`.
2. **Setup PubSub:** Initialize a Phoenix PubSub topic for the "Global Event Bus" where Skills broadcast their outputs.
3. **Mock a "Notification Skill":** A dedicated Actor that listens to all channels and renders the playback UI.

---

## 30min Implementation Plan

### Phase 1: The Skill Blueprint (10 mins)

Define a generic `Skill` LiveComponent that acts as the actor's shell. It subscribes to its `input_channel` on mount.

```elixir
defmodule Project.SkillComponent do
  use Phoenix.LiveComponent

  # Skill as a Pure Function wrapper
  def handle_event("ui_input", params, socket) do
    # 1. Process local UI change
    # 2. Emit to output_channel via PubSub
    Phoenix.PubSub.broadcast(Project.PubSub, socket.assigns.output_channel, %{
      from: socket.assigns.skill_id,
      data: params
    })
    {:noreply, socket}
  end
end
```

### Phase 2: The Communication Orchestrator (10 mins)

Create a "Skill Manager" that composes these units. Based on your uploaded images (like the functional UI composition), this manager handles the "wiring" (connecting Skill A's output to Skill B's input).

* **Wiring Logic:** Create a map where `%{source_channel => [target_channels]}`.
* **Notification Sink:** Every broadcast is also sent to a `HistoryTracker` actor.

### Phase 3: The Time-Travel UI (10 mins)

Build the "Notification" footer. Since every Skill change is a message, "playing backward" simply means:

1. Picking a previous index in the Notification Log.
2. Pushing that specific state back to the relevant Skill PIDs using `send(pid, {:force_state, state})`.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LIVEVIEW PARENT                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    SKILL MANAGER (Orchestrator)                      │   │
│  │  wiring: %{                                                          │   │
│  │    "file_count:output" => ["component_calc:input", "scope:input"],   │   │
│  │    "component_calc:output" => ["effort:input"]                       │   │
│  │  }                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│         ┌──────────────────────────┼──────────────────────────┐             │
│         ▼                          ▼                          ▼             │
│  ┌─────────────┐           ┌─────────────┐           ┌─────────────┐       │
│  │ SKILL:      │           │ SKILL:      │           │ SKILL:      │       │
│  │ file_count  │──output──▶│ component   │──output──▶│ effort_calc │       │
│  │             │           │ _calculator │           │             │       │
│  │ Pure Fn:    │           │ Pure Fn:    │           │ Pure Fn:    │       │
│  │ count files │           │ files * 15  │           │ sum days    │       │
│  └─────────────┘           └─────────────┘           └─────────────┘       │
│         │                          │                          │             │
│         └──────────────────────────┼──────────────────────────┘             │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    HISTORY TRACKER (The Tape)                        │   │
│  │  events: [                                                           │   │
│  │    {t1, :file_count, :output, 55000},                               │   │
│  │    {t2, :component_calc, :output, 825000},                          │   │
│  │    {t3, :effort_calc, :output, 82.5}                                │   │
│  │  ]                                                                   │   │
│  │  position: 3 | mode: :live                                          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    ▼                                         │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │              NOTIFICATION UI (Time-Travel Controls)                  │   │
│  │  [⏮️ Start] [⏪ Back] [▶️ Play] [⏩ Forward] [⏭️ End]                │   │
│  │  ═══════════════════●════════════════════════════                   │   │
│  │  Event 3/10: component_calc changed 825000 → 840000                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## HTML Element IDs for Testing

All interactive elements will have predictable IDs for Puppeteer/Playwright testing:

### Skill Components
- `skill-{name}` - Container for each skill
- `skill-{name}-input-{field}` - Input fields
- `skill-{name}-output-{field}` - Output displays
- `skill-{name}-status` - Skill status indicator

### Project Scope Section
- `project-scope` - Main container
- `project-scope-total-files` - Total files display
- `project-scope-project-type` - Project type badge
- `project-scope-simple-count` - Simple files input
- `project-scope-medium-count` - Medium files input
- `project-scope-complex-count` - Complex files input

### Activities Table
- `activities-table` - Main table container
- `activity-row-{id}` - Each activity row
- `activity-{id}-assignment-{member}` - Team assignment checkbox
- `activity-{id}-days` - Days per unit
- `activity-{id}-auto-pct` - Automation percentage
- `activity-{id}-total-base` - Base days total
- `activity-{id}-total-final` - Final days total

### Component Calculator
- `component-calculator` - Main container
- `component-{type}-count` - Count input
- `component-{type}-avg-units` - Average units input
- `component-{type}-total-units` - Total units display
- `component-{type}-base-days` - Base days display
- `component-{type}-final-days` - Final days display

### Timeline/Notification
- `timeline-container` - Main timeline container
- `timeline-event-{index}` - Each event in the log
- `timeline-controls` - Control buttons container
- `timeline-btn-start` - Go to start button
- `timeline-btn-back` - Step back button
- `timeline-btn-play` - Play/pause button
- `timeline-btn-forward` - Step forward button
- `timeline-btn-end` - Go to end button
- `timeline-scrubber` - Position slider
- `timeline-position` - Current position display
- `timeline-mode` - Current mode indicator (live/replay)

---

## Test Scenarios

### Simple Tests
1. Page loads with correct initial values
2. Skill components render with proper IDs
3. Input fields are editable
4. Timeline shows events

### Medium Tests
1. Changing file count updates component calculations
2. Activity assignments toggle correctly
3. Timeline playback works (forward/backward)
4. Skills communicate via PubSub (value propagation)

### Integration Tests
1. Full calculation flow: files → components → effort → buffers
2. Time-travel: replay to past state and verify UI
3. Multiple skill updates cascade correctly
