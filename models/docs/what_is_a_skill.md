# What Is a Skill?

## Definition

A **Skill** is the atomic unit of computation in a functional-reactive system. It is a self-contained actor that wraps a **pure function** with well-defined inputs, outputs, state, and behavior.

In our NeoExcelPPT system, a Skill is expressed as an **S-expression** (symbolic expression) that encodes:

```
(define-skill :skill-id
  (inputs :channel1 :channel2)
  (outputs :output1 :output2)
  (state {:key value})
  (compute
    (expression)))
```

## The Skill Contract

Every Skill follows this contract:

```
compute(state, input) -> {new_state, outputs}
```

This is a **pure function**: given the same state and input, it always produces the same output. No side effects. No hidden dependencies. This makes Skills:

- **Testable** - deterministic input/output
- **Composable** - pipe outputs of one into inputs of another
- **Replayable** - time-travel debugging via event sourcing
- **Serializable** - represent as data (S-expressions)

## Skills as Actors

In the Erlang/OTP tradition, each Skill runs as a **GenServer** (lightweight process):

```
                    +-------------------+
   input channels   |                   |  output channels
  ================> |   Skill Actor     | =================>
   :file-counts     |                   |   :total-files
                    |  state: {...}     |   :breakdown
                    |  compute: (fn)    |
                    +-------------------+
                           |
                           v
                    [History Tracker]
                    (event log / tape)
```

Each Skill:
1. **Subscribes** to input channels via PubSub
2. **Computes** new state and outputs via its pure function
3. **Broadcasts** outputs to output channels
4. **Records** all state transitions to the History Tracker

## Skills vs Functions

| Property | Regular Function | Skill |
|----------|-----------------|-------|
| State | Stateless | Carries state across invocations |
| Communication | Direct call | Channel-based (PubSub) |
| Lifecycle | None | Managed by supervisor tree |
| History | None | Full event log with time-travel |
| Representation | Code | Data (S-expression) |
| Composability | Manual | Declarative wiring |

## The Key Insight: Code as Data, Data as Code

Skills blur the line between code and data:

```
;; This IS the skill definition AND the executable specification
(define-skill :project-scope
  (inputs :file-counts)
  (outputs :total-files :component-breakdown)
  (state {:simple 0 :medium 0 :complex 0})
  (compute
    (let [files (get input :file-counts)
          total (+ (get files :simple) (get files :medium) (get files :complex))]
      (emit :total-files total)
      (emit :component-breakdown files))))
```

This S-expression is simultaneously:
- A **document** (human-readable specification)
- A **program** (machine-executable computation)
- A **schema** (typed inputs/outputs/state)
- A **test fixture** (deterministic contract)

## Skills in the AI Context

When used with Hugging Face's `upskill` library, Skills become **transferable knowledge units**:

1. A **Teacher model** (e.g., Claude Opus) generates Skill definitions
2. The Skill is encoded as a SKILL.md document with S-expressions
3. A **Student model** (e.g., SmolLM) loads the Skill to perform the task
4. The Skill is **evaluated** by comparing teacher vs student performance

This creates a pipeline:

```
[Teacher Model] --generates--> [SKILL.md + S-Exprs] --teaches--> [Student Model]
                                      |
                                      v
                              [Evaluation Metrics]
                              - skill_lift (accuracy)
                              - token_savings (cost)
                              - is_beneficial (pass/fail)
```

## Nested Skill Composition

Skills compose through **wiring** - connecting outputs to inputs:

```
(define-wiring
  (connect :project-scope:total-files -> :component-calculator:file-count)
  (connect :component-calculator:scaled-effort -> :effort-aggregator:component-effort)
  (connect :effort-aggregator:total-days -> :buffer-calculator:base-days))
```

This creates a **dataflow graph** where changes cascade automatically:

```
[Project Scope] --> [Component Calculator] --> [Effort Aggregator] --> [Buffer Calculator]
     |                                                |
     +---> [Activity Calculator] ------>--------------+
```

## Summary

A Skill is the fundamental building block of our system. It is:

- **An actor** with lifecycle management
- **A pure function** with deterministic behavior
- **An S-expression** that is both code and data
- **A teachable unit** that can be transferred between AI models
- **A composable block** that wires into larger computations

Skills are how we turn spreadsheet logic into a programmable, testable, AI-trainable system.
