# How to Combine & Play with the Skills Generator

## Overview

This guide shows how to combine Hugging Face's `upskill` library with our S-expression DSL to create a **self-generating skill system**. The workflow:

```
[Task Description] --> [upskill generate] --> [SKILL.md] --> [S-Expr Parser] --> [Running Skill Actor]
```

## Setup

### 1. Install Dependencies

```bash
cd models/
pip install -r requirements.txt
```

### 2. Set API Keys

```bash
export ANTHROPIC_API_KEY=sk-ant-...
# OR for local models:
export GENERIC_BASE_URL=http://localhost:11434/v1
```

### 3. Configure upskill

Create `~/.config/upskill/config.yaml`:
```yaml
model: sonnet
eval_model: haiku
skills_dir: ./skills
runs_dir: ./runs
max_refine_attempts: 3
```

## Workflow 1: Generate Skills from Task Descriptions

### Step 1: Describe the Skill You Want

```bash
upskill generate "Create a spreadsheet cell computation skill that takes a formula string, parses it, evaluates it against a dependency map, and returns the computed value. Output as an S-expression in the NeoExcelPPT DSL format."
```

### Step 2: Review the Generated SKILL.md

```bash
cat ./skills/cell-computation/SKILL.md
```

### Step 3: Convert SKILL.md to S-Expression

```python
from models.skills.sexpr_generator import SExprGenerator

generator = SExprGenerator()

# Load the skill document
with open("./skills/cell-computation/SKILL.md") as f:
    skill_doc = f.read()

# Generate S-expression from the skill document
sexpr = generator.skill_doc_to_sexpr(skill_doc)
print(sexpr)
```

Output:
```
(define-skill :cell-computation
  (inputs :formula-string :dependency-map)
  (outputs :computed-value :parse-errors)
  (state {:cache {} :last-formula nil})
  (compute
    (let [formula (get input :formula-string)
          deps (get input :dependency-map)
          ast (parse-formula formula)
          result (eval-ast ast deps)]
      (set :cache (assoc (get state :cache) formula result))
      (set :last-formula formula)
      (emit :computed-value result))))
```

## Workflow 2: Generate Skills from Existing UI (localhost:4000)

### Step 1: Interpret the UI

```python
from models.skills.localhost_interpreter import LocalhostInterpreter

interpreter = LocalhostInterpreter()

# Analyze the Phoenix LiveView page structure
skills = interpreter.interpret_from_html("project_live.ex")
print(f"Found {len(skills)} skill candidates")
```

### Step 2: Generate S-Expressions from UI Analysis

```python
for skill in skills:
    sexpr = generator.generate_from_skill_definition(skill)
    print(f"\n;; Skill: {skill['name']}")
    print(sexpr)
```

### Step 3: Validate Generated S-Expressions

```python
from models.skills.sexpr_generator import SExprParser

parser = SExprParser()
for sexpr_str in generated_sexprs:
    result = parser.parse(sexpr_str)
    if result['valid']:
        print(f"  Valid: {result['skill_id']}")
    else:
        print(f"  ERROR: {result['error']}")
```

## Workflow 3: Teacher-Student Pipeline

### Step 1: Generate with Teacher Model

```python
from models.skills.upskill_bridge import UpskillBridge

bridge = UpskillBridge(
    teacher_model="sonnet",
    student_model="haiku"
)

# Generate a skill for S-expression creation
skill = bridge.generate_skill(
    task="Generate valid NeoExcelPPT S-expression skill definitions",
    examples=[
        {
            "input": "Create a skill that sums two numbers",
            "output": '(define-skill :adder (inputs :a :b) (outputs :sum) (compute (emit :sum (+ (get input :a) (get input :b)))))'
        }
    ]
)
```

### Step 2: Evaluate on Student Model

```python
results = bridge.evaluate_skill(
    skill=skill,
    test_cases=[
        {"input": "Create a skill that multiplies price by quantity", "expected": {"contains": ["define-skill", "compute", "emit", "*"]}},
        {"input": "Create a buffer calculator skill", "expected": {"contains": ["define-skill", ":buffer", "inputs", "outputs"]}},
    ]
)

print(f"Skill Lift: {results['skill_lift']:.0%}")
print(f"Token Savings: {results['token_savings']:.0%}")
print(f"Beneficial: {results['is_beneficial']}")
```

### Step 3: Iterate and Refine

```python
if not results['is_beneficial']:
    refined_skill = bridge.refine_skill(
        skill=skill,
        feedback=results['failure_analysis'],
        max_attempts=3
    )
```

## Workflow 4: Playing with Composition

### Compose Skills via Wiring

```python
from models.skills.sexpr_generator import WiringGenerator

wiring = WiringGenerator()

# Define the skill graph
wiring.connect("project-scope", "total-files", "component-calculator", "file-count")
wiring.connect("component-calculator", "scaled-effort", "effort-aggregator", "component-effort")
wiring.connect("activity-calculator", "activity-totals", "effort-aggregator", "activity-effort")
wiring.connect("effort-aggregator", "total-days", "buffer-calculator", "base-days")

# Generate wiring S-expression
print(wiring.to_sexpr())
```

Output:
```
(define-wiring
  (connect :project-scope:total-files -> :component-calculator:file-count)
  (connect :component-calculator:scaled-effort -> :effort-aggregator:component-effort)
  (connect :activity-calculator:activity-totals -> :effort-aggregator:activity-effort)
  (connect :effort-aggregator:total-days -> :buffer-calculator:base-days))
```

### Compose UX Actions

```python
from models.skills.sexpr_generator import ActionComposer

actions = ActionComposer()

# Build a complex action from simple parts
action = actions.on_click(
    actions.if_then_else(
        actions.call("valid?"),
        actions.seq(
            actions.call("db/save"),
            actions.call("notify", "Saved successfully!"),
            actions.call("close")
        ),
        actions.call("warn", "Please fix errors first")
    )
)

print(action.to_sexpr())
```

Output:
```
(on-click
  (if (valid?)
    (seq (db/save) (notify "Saved successfully!") (close))
    (warn "Please fix errors first")))
```

## Workflow 5: Full Pipeline Demo

```python
# The complete pipeline: description -> skill -> test -> evaluate -> deploy
from models.skills.upskill_bridge import UpskillBridge
from models.skills.sexpr_generator import SExprGenerator, SExprParser
from models.skills.localhost_interpreter import LocalhostInterpreter

# 1. Interpret existing UI
interpreter = LocalhostInterpreter()
ui_skills = interpreter.interpret_from_html("project_live.ex")

# 2. Generate S-expressions for each discovered skill
generator = SExprGenerator()
sexprs = [generator.generate_from_skill_definition(s) for s in ui_skills]

# 3. Validate all generated S-expressions
parser = SExprParser()
valid_sexprs = [s for s in sexprs if parser.parse(s)['valid']]
print(f"Generated {len(valid_sexprs)}/{len(sexprs)} valid S-expressions")

# 4. Use upskill to teach a small model to generate these
bridge = UpskillBridge(teacher_model="sonnet", student_model="haiku")
skill = bridge.generate_skill(
    task="Generate NeoExcelPPT S-expression skills from UI descriptions",
    examples=[{"input": ui_skills[0]['description'], "output": sexprs[0]}]
)

# 5. Evaluate
results = bridge.evaluate_skill(skill, test_cases=[
    {"input": s['description'], "expected": {"contains": ["define-skill"]}}
    for s in ui_skills[1:]
])

print(f"\nPipeline Results:")
print(f"  Skills discovered from UI: {len(ui_skills)}")
print(f"  Valid S-expressions generated: {len(valid_sexprs)}")
print(f"  Student model skill lift: {results['skill_lift']:.0%}")
print(f"  Beneficial: {results['is_beneficial']}")
```

## Running the Tests

```bash
# Run all example tests
cd /home/user/neoExcelPPT
python -m pytest models/tests/example_skills_tests.py -v

# Run specific test categories
python -m pytest models/tests/example_skills_tests.py -k "test_sexpr" -v
python -m pytest models/tests/example_skills_tests.py -k "test_skill" -v
python -m pytest models/tests/example_skills_tests.py -k "test_upskill" -v
```

## Tips for Playing

1. **Start small** - generate a single simple skill (adder, counter) before attempting complex ones
2. **Validate early** - always parse generated S-expressions before using them
3. **Use the visual editor** - load generated S-expressions into the SvelteFlow editor at `/flow`
4. **Compare models** - try generating the same skill with different teacher/student combinations
5. **Check token counts** - S-expressions should be 3-6x smaller than equivalent JSON
6. **Iterate** - the upskill refine loop is your friend; let it run 2-3 attempts
7. **Test composition** - wire generated skills together and verify data flows correctly

## Common Patterns

### Pattern: Generate-Parse-Validate-Wire

```python
# This is the core loop you'll use most often
sexpr_string = generator.generate(task_description)
ast = parser.parse(sexpr_string)
if ast['valid']:
    skill_def = parser.ast_to_skill(ast)
    wiring.add_skill(skill_def)
    wiring.auto_connect()  # infer connections from input/output names
```

### Pattern: UI-to-Skill Extraction

```python
# Extract skills from any HTML/LiveView page
for element in interpreter.find_interactive_elements(html):
    skill = interpreter.element_to_skill(element)
    sexpr = generator.generate_from_skill_definition(skill)
    # skill now encodes the element's computation + UI + state
```

### Pattern: Skill Marketplace

```python
# Package a skill for sharing
skill_package = {
    "name": "project-estimator",
    "version": "1.0.0",
    "skills": valid_sexprs,
    "wiring": wiring.to_sexpr(),
    "tests": test_cases,
    "eval_results": results
}
# Save as a shareable bundle
save_skill_package(skill_package, "./marketplace/project-estimator/")
```
