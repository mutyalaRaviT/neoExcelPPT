# What Skills Are Important?

## The Skill Taxonomy for Excel Replacement

To overtake Excel, we need a comprehensive set of skills organized into layers. Each skill is an S-expression that encodes computation, UI, and behavior.

## Layer 1: Foundation Skills (The Spreadsheet Core)

These are the non-negotiable skills that make a spreadsheet a spreadsheet.

### 1.1 Cell Computation Skill

```
(define-skill :cell-compute
  (inputs :cell-value :cell-formula :cell-dependencies)
  (outputs :computed-value :dependency-graph)
  (state {:value nil :formula nil :deps []})
  (compute
    (if (get input :cell-formula)
      (let [result (eval-formula (get input :cell-formula))]
        (emit :computed-value result)
        (emit :dependency-graph (extract-deps (get input :cell-formula))))
      (emit :computed-value (get input :cell-value)))))
```

**Why important:** Every cell must compute values and track dependencies. This is the atom of spreadsheets.

### 1.2 Formula Parsing Skill

```
(define-skill :formula-parser
  (inputs :raw-formula)
  (outputs :parsed-ast :validation-result)
  (state {:supported-functions ["SUM" "AVG" "IF" "VLOOKUP" "COUNT"]})
  (compute
    (let [ast (parse-formula (get input :raw-formula))
          valid (validate-ast ast (get state :supported-functions))]
      (emit :parsed-ast ast)
      (emit :validation-result valid))))
```

**Why important:** Formulas are Excel's core language. Without parsing, there is no spreadsheet.

### 1.3 Dependency Graph Skill

```
(define-skill :dependency-tracker
  (inputs :cell-update :dependency-change)
  (outputs :recalc-order :cycle-detected)
  (state {:graph {} :topo-order []})
  (compute
    (let [graph (update-graph (get state :graph) (get input :dependency-change))
          cycle (detect-cycle graph)]
      (if cycle
        (emit :cycle-detected {:cells cycle :message "Circular reference"})
        (let [order (topological-sort graph)]
          (set :graph graph)
          (set :topo-order order)
          (emit :recalc-order order))))))
```

**Why important:** Prevents infinite loops (A1=B1, B1=A1) and determines calculation order.

## Layer 2: Data Skills (Beyond Cell Values)

### 2.1 Project Scope Skill (From Our System)

```
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

**Why important:** Real-world project estimation - the use case that proves we're more than a toy.

### 2.2 Component Calculator Skill

```
(define-skill :component-calculator
  (inputs :file-count :breakdown :automation-pct)
  (outputs :scaled-effort :component-days)
  (state {:base-hours-per-file 15})
  (compute
    (let [files (get input :file-count)
          hours (get state :base-hours-per-file)
          auto-pct (get input :automation-pct)
          base-effort (* files hours)
          scaled (* base-effort (- 1 (/ auto-pct 100)))]
      (emit :scaled-effort scaled)
      (emit :component-days (/ scaled 8)))))
```

**Why important:** Demonstrates skill composition with arithmetic and state.

### 2.3 Activity Calculator Skill

```
(define-skill :activity-calculator
  (inputs :activity-update :team-assignment)
  (outputs :activity-totals :team-effort)
  (state {:activities {}})
  (compute
    (let [update (get input :activity-update)]
      (set :activities (merge (get state :activities) update))
      (emit :activity-totals (sum-values (get state :activities))))))
```

### 2.4 Buffer Calculator Skill

```
(define-skill :buffer-calculator
  (inputs :base-days :buffer-config)
  (outputs :buffer-days :buffer-breakdown)
  (state {:leave-pct 10 :dependency-pct 15 :learning-pct 20})
  (compute
    (let [base (get input :base-days)
          leave (* base (/ (get state :leave-pct) 100))
          dep (* base (/ (get state :dependency-pct) 100))
          learn (* base (/ (get state :learning-pct) 100))]
      (emit :buffer-days (+ leave dep learn))
      (emit :buffer-breakdown {:leave leave :dependency dep :learning learn}))))
```

### 2.5 Effort Aggregator Skill

```
(define-skill :effort-aggregator
  (inputs :component-effort :activity-effort :buffer-days)
  (outputs :total-days :effort-breakdown)
  (state {:component 0 :activity 0 :buffer 0})
  (compute
    (let [comp (get input :component-effort)
          act (get input :activity-effort)
          buf (get input :buffer-days)
          total (+ comp act buf)]
      (emit :total-days total)
      (emit :effort-breakdown {:component comp :activity act :buffer buf}))))
```

## Layer 3: UI Skills (Rendering & Interaction)

### 3.1 Grid Rendering Skill

```
(define-skill :ui-grid
  (inputs :data-source :column-config :selection)
  (outputs :rendered-grid :cell-events)
  (state {:scroll-pos 0 :selected-cell nil :editing false})
  (compute
    (emit :rendered-grid
      (ui/grid :id "main-grid"
        (map (fn [col] (ui/col :field (get col :field)
                                :header (get col :header)
                                :editable (get col :editable)))
             (get input :column-config))))))
```

**Why important:** The visual grid IS the product. AG Grid integration is essential.

### 3.2 Section Layout Skill

```
(define-skill :ui-layout
  (inputs :sections :visibility-config)
  (outputs :rendered-layout)
  (state {:collapsed-sections #{}})
  (compute
    (emit :rendered-layout
      (ui/container :class "grid grid-cols-3 gap-6"
        (map (fn [section]
          (if (not (contains? (get state :collapsed-sections) (get section :id)))
            (ui/section :id (get section :id)
                        :title (get section :title)
                        (get section :content))))
        (get input :sections))))))
```

### 3.3 Input Binding Skill

```
(define-skill :ui-input-binding
  (inputs :user-input :validation-rules)
  (outputs :validated-value :validation-errors)
  (state {:dirty false :original-value nil})
  (compute
    (let [value (get input :user-input)
          rules (get input :validation-rules)
          errors (validate value rules)]
      (if (empty? errors)
        (do (set :dirty true)
            (emit :validated-value value))
        (emit :validation-errors errors)))))
```

## Layer 4: AI Integration Skills

### 4.1 S-Expression Generation Skill

```
(define-skill :sexpr-generator
  (inputs :task-description :context)
  (outputs :generated-sexpr :generation-metadata)
  (state {:model "sonnet" :temperature 0.3 :max-tokens 2000})
  (compute
    (let [prompt (build-prompt (get input :task-description) (get input :context))
          result (llm-generate (get state :model) prompt)]
      (emit :generated-sexpr (parse-sexpr result))
      (emit :generation-metadata {:tokens-used (count-tokens result)
                                   :model (get state :model)}))))
```

**Why important:** This is the meta-skill - the skill that generates other skills.

### 4.2 Skill Evaluation Skill

```
(define-skill :skill-evaluator
  (inputs :skill-definition :test-cases)
  (outputs :evaluation-result :improvement-suggestions)
  (state {:pass-threshold 0.8 :history []})
  (compute
    (let [results (map (fn [test]
                    (run-test (get input :skill-definition) test))
                  (get input :test-cases))
          pass-rate (/ (count (filter :passed results)) (count results))]
      (set :history (conj (get state :history) {:rate pass-rate :time (now)}))
      (emit :evaluation-result {:pass-rate pass-rate
                                 :passed (>= pass-rate (get state :pass-threshold))
                                 :details results}))))
```

### 4.3 Upskill Bridge Skill

```
(define-skill :upskill-bridge
  (inputs :skill-request :teacher-model :student-model)
  (outputs :generated-skill :evaluation-metrics)
  (state {:skills-dir "./skills" :runs-dir "./runs"})
  (compute
    (let [skill (upskill-generate (get input :skill-request)
                                   :model (get input :teacher-model))
          tests (upskill-gen-tests (get input :skill-request))
          eval (upskill-evaluate skill tests
                                 :model (get input :student-model))]
      (emit :generated-skill skill)
      (emit :evaluation-metrics
        {:lift (get eval :skill-lift)
         :savings (get eval :token-savings)
         :beneficial (get eval :is-beneficial)}))))
```

## Layer 5: Orchestration Skills

### 5.1 Wiring Manager Skill

```
(define-skill :wiring-manager
  (inputs :wiring-update :skill-registry)
  (outputs :active-wiring :wiring-validation)
  (state {:wiring {} :version 0})
  (compute
    (let [new-wiring (merge (get state :wiring) (get input :wiring-update))
          valid (validate-wiring new-wiring (get input :skill-registry))]
      (if (get valid :ok)
        (do (set :wiring new-wiring)
            (set :version (+ (get state :version) 1))
            (emit :active-wiring new-wiring))
        (emit :wiring-validation (get valid :errors))))))
```

### 5.2 History & Time-Travel Skill

```
(define-skill :history-tracker
  (inputs :state-change :replay-command)
  (outputs :current-position :event-log)
  (state {:events [] :position 0 :playing false})
  (compute
    (case (get input :replay-command)
      :play (set :playing true)
      :pause (set :playing false)
      :back (set :position (max 0 (- (get state :position) 1)))
      :forward (set :position (min (count (get state :events))
                                    (+ (get state :position) 1)))
      :start (set :position 0)
      :end (set :position (count (get state :events)))
      nil (do (set :events (conj (get state :events) (get input :state-change)))
              (set :position (count (get state :events)))))
    (emit :current-position (get state :position))
    (emit :event-log (get state :events))))
```

## Skill Priority Matrix

| Priority | Skill | Layer | Reason |
|----------|-------|-------|--------|
| P0 | Cell Computation | Foundation | Core spreadsheet functionality |
| P0 | Dependency Graph | Foundation | Prevents circular references |
| P0 | Formula Parser | Foundation | Enables formulas |
| P1 | Project Scope | Data | Our primary use case |
| P1 | Component Calculator | Data | Estimation engine |
| P1 | Grid Rendering | UI | The visible product |
| P2 | S-Expr Generator | AI | Meta-skill generation |
| P2 | Upskill Bridge | AI | Model training pipeline |
| P2 | History Tracker | Orchestration | Time-travel debugging |
| P3 | Activity Calculator | Data | Advanced estimation |
| P3 | Buffer Calculator | Data | Risk planning |
| P3 | Effort Aggregator | Data | Summary aggregation |

## The Complete Wiring

```
(define-wiring
  ;; Foundation layer
  (connect :formula-parser:parsed-ast -> :cell-compute:cell-formula)
  (connect :cell-compute:dependency-graph -> :dependency-tracker:dependency-change)
  (connect :dependency-tracker:recalc-order -> :cell-compute:cell-dependencies)

  ;; Data layer
  (connect :project-scope:total-files -> :component-calculator:file-count)
  (connect :project-scope:component-breakdown -> :component-calculator:breakdown)
  (connect :component-calculator:scaled-effort -> :effort-aggregator:component-effort)
  (connect :activity-calculator:activity-totals -> :effort-aggregator:activity-effort)
  (connect :effort-aggregator:total-days -> :buffer-calculator:base-days)

  ;; AI layer
  (connect :sexpr-generator:generated-sexpr -> :skill-evaluator:skill-definition)
  (connect :upskill-bridge:generated-skill -> :skill-evaluator:skill-definition)

  ;; Orchestration
  (connect :cell-compute:computed-value -> :history-tracker:state-change)
  (connect :wiring-manager:active-wiring -> :history-tracker:state-change))
```

## Summary

The skills that matter most are:

1. **Foundation skills** that replicate Excel's core (cell computation, formulas, dependency tracking)
2. **Domain skills** that demonstrate value beyond Excel (project estimation, effort calculation)
3. **AI skills** that enable the system to generate and evaluate itself (sexpr generation, upskill bridge)
4. **Orchestration skills** that tie everything together (wiring, history, time-travel)

Each skill is a composable, testable, AI-trainable unit expressed as an S-expression.
