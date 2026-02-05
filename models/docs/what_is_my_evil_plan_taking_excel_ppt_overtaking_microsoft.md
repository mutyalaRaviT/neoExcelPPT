# The Evil Plan: Taking Over Excel & PPT, Overtaking Microsoft

## The Vision

Microsoft Excel is a $30B+ product built in the 1980s on a paradigm of **static grids with imperative macros**. It has not fundamentally changed in 40 years. The time has come.

Our weapon: **Skills as S-Expressions + AI Generation + Functional Reactive Architecture**.

## Why Microsoft Excel Is Vulnerable

### Excel's Fundamental Weaknesses

```
(define-weakness :excels-architecture
  (problems
    :imperative-macros    ;; VBA is a 1990s language with global mutable state
    :no-composition       ;; formulas don't compose - they reference cells by address
    :no-history           ;; undo is limited, no time-travel, no event sourcing
    :no-dependency-viz    ;; circular references are silent killers
    :no-ai-native         ;; Copilot is bolted on, not built in
    :no-actor-model       ;; single-threaded recalculation
    :file-based           ;; .xlsx is a dead format - no real-time collaboration core
    :no-skill-transfer    ;; knowledge dies with the spreadsheet creator
  ))
```

### PowerPoint's Fundamental Weaknesses

```
(define-weakness :powerpoints-architecture
  (problems
    :manual-layout        ;; drag-and-drop pixel pushing
    :no-data-binding      ;; charts disconnect from data sources
    :no-live-updates      ;; static slides in a dynamic world
    :no-computation       ;; no formulas, no logic
    :template-prison      ;; themes don't compose or evolve
  ))
```

## The Attack Plan

### Phase 1: Skills Foundation (Current Sprint)

```
(define-phase :foundation
  (goal "Prove that S-expression skills can replicate Excel's core")
  (deliverables
    :sexpr-dsl-parser          ;; DONE - lib/neo_excel_ppt/skills/dsl.ex
    :actor-based-skills        ;; DONE - 5 skills as GenServers
    :visual-flow-editor        ;; DONE - SvelteFlow + DSL editor
    :time-travel-debugging     ;; DONE - HistoryTracker with replay
    :project-estimation-demo   ;; DONE - localhost:4000 working prototype
  )
  (status :complete))
```

### Phase 2: AI Skill Generation (This Sprint)

```
(define-phase :ai-generation
  (goal "Use Hugging Face upskill to generate and evaluate skills automatically")
  (deliverables
    :upskill-integration       ;; Python bridge to HF upskill library
    :sexpr-from-ai             ;; Teacher models generate skill S-expressions
    :skill-evaluation          ;; Automated testing of generated skills
    :small-model-distillation  ;; Teach SmolLM to generate valid S-expressions
    :localhost-interpreter     ;; Convert existing UI to skill definitions
  )
  (status :in-progress))
```

### Phase 3: Cell-Level Intelligence

```
(define-phase :cell-intelligence
  (goal "Every cell becomes an AI-aware skill with formula understanding")
  (deliverables
    :natural-language-formulas ;; "sum the sales column" -> (sum (col :sales))
    :auto-dependency-graph     ;; AI detects implicit dependencies
    :formula-suggestion        ;; context-aware formula completion
    :error-explanation         ;; "This formula fails because..."
    :type-inference            ;; automatic type detection and validation
  )
  (status :planned))
```

### Phase 4: The Excel Killer Features

```
(define-phase :excel-killer
  (goal "Features Excel cannot replicate due to architectural limitations")
  (deliverables
    :real-time-collaboration   ;; CRDT-based concurrent editing
    :skill-marketplace         ;; share and compose skills like npm packages
    :time-travel-branching     ;; fork spreadsheet history, merge changes
    :live-data-streams         ;; cells subscribe to external data feeds
    :cross-sheet-skills        ;; skills that span multiple sheets/workbooks
    :visual-programming        ;; SvelteFlow for non-programmers
    :ai-copilot-native         ;; not bolted on - the AI IS the architecture
  )
  (status :planned))
```

### Phase 5: The PPT Killer

```
(define-phase :ppt-killer
  (goal "Presentations that are live computations, not static slides")
  (deliverables
    :live-data-slides          ;; slides that update from skill outputs
    :narrative-from-skills     ;; AI generates story from computation graph
    :interactive-presentations ;; audience can tweak inputs, see results live
    :skill-to-chart            ;; any skill output can become a chart
    :auto-layout               ;; constraint-based layout from S-expressions
  )
  (status :planned))
```

## The Technical Moat

### Why This Can't Be Easily Copied

```
(define-moat :technical-advantages
  (advantages
    ;; 1. S-Expressions as universal interchange format
    ;;    - Code = Data = Schema = Tests = Documentation
    ;;    - 5.5x more token-efficient than JSON
    ;;    - AI models generate them reliably

    ;; 2. Actor model for concurrent computation
    ;;    - Erlang/OTP battle-tested since 1986
    ;;    - Each cell/skill is an isolated process
    ;;    - Crash isolation: one cell failure doesn't kill the sheet

    ;; 3. Event sourcing with time-travel
    ;;    - Complete audit trail of every change
    ;;    - Branch, merge, replay any computation
    ;;    - Perfect for compliance and debugging

    ;; 4. AI-native architecture
    ;;    - Skills are generated by AI, evaluated by AI, improved by AI
    ;;    - Teacher-student pipeline via upskill
    ;;    - Self-improving system that gets better with use

    ;; 5. Functional reactive dataflow
    ;;    - DataScript/re-posh reactive graph database
    ;;    - Changes cascade automatically and correctly
    ;;    - No manual refresh, no stale data
  ))
```

## The Revenue Strategy

```
(define-strategy :revenue
  (tiers
    :free       ;; Local skills, basic grid, 1000 cells
    :pro        ;; AI skill generation, unlimited cells, collaboration
    :enterprise ;; Custom skill marketplace, on-prem, compliance tools
    :platform   ;; API access, skill SDK, embedded spreadsheet-as-a-service
  )
  (pricing
    :free       0
    :pro        19/month
    :enterprise 49/user/month
    :platform   usage-based
  ))
```

## The Competitive Landscape

```
;; What others are doing vs what we're building

(define-comparison
  ;; Google Sheets: real-time collab but same formula paradigm
  ;;   -> We have: skills, actors, AI-native, time-travel

  ;; Airtable: database-like but no computation graph
  ;;   -> We have: full computation with dependency tracking

  ;; Notion: great UX but not a spreadsheet
  ;;   -> We have: actual cell-level computation + skill composition

  ;; Excel + Copilot: AI bolted onto 40-year architecture
  ;;   -> We have: AI IS the architecture, not an add-on

  ;; Rows.com: API-connected spreadsheet
  ;;   -> We have: skills as composable actors, not just API calls
)
```

## The 12-Month Roadmap

```
(define-roadmap
  (month-1-3  :foundation
    "S-expr DSL, actor skills, visual editor, time-travel")
  (month-3-6  :ai-integration
    "upskill pipeline, sexpr generation, skill evaluation, small model training")
  (month-6-9  :product
    "Cell-level AI, natural language formulas, collaboration, marketplace MVP")
  (month-9-12 :scale
    "Enterprise features, PPT generation, platform API, 10K users"))
```

## The Evil Plan Summary

```
(define-evil-plan :overtake-microsoft
  (weapon "Skills as S-Expressions")
  (strategy "AI generates what humans used to manually build")
  (moat "Functional reactive actors with time-travel")
  (timeline "12 months to feature parity, 18 months to superiority")
  (outcome "Excel is a file format. We are a skill network."))
```

The key insight: **Excel thinks in cells. We think in skills.**

A cell is a dead value in a static grid.
A skill is a living computation in a reactive network.

That's the difference between a spreadsheet and an intelligence.
