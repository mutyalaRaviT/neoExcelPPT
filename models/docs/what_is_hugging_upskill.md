# What Is Hugging Face Upskill?

## Overview

**Upskill** is a framework by Hugging Face for automatically generating and evaluating **agent skills** using large language models. It implements a **teacher-student paradigm** where powerful models create skill documents that less capable models can use to improve their performance on specific tasks.

GitHub: [huggingface/upskill](https://github.com/huggingface/upskill)

## Installation

```bash
pip install upskill
# or run directly
uvx upskill --help
```

## Core Concept: Teacher-Student Paradigm

```
+------------------+     generates     +------------------+     teaches     +------------------+
|  Teacher Model   | ================> |    SKILL.md      | ===============>|  Student Model   |
|  (Claude Opus)   |                   |  + test cases    |                 |  (SmolLM/Haiku)  |
|  (GPT-4)         |                   |  + references    |                 |  (local model)   |
+------------------+                   +------------------+                 +------------------+
                                              |
                                              v
                                       [Evaluation]
                                       - skill_lift > 5%
                                       - token_savings > 20%
                                       - is_beneficial = true/false
```

A teacher model (expensive, high-capability) analyzes a task and generates a `SKILL.md` document containing instructions, examples, and guidance. A student model then loads this skill into its context when executing tasks.

## How It Works

### 1. Generate a Skill

```bash
# From a task description
upskill generate "write good git commit messages"

# From an existing trace/document
upskill generate "document the pattern" --from ./trace.md

# With specific teacher and student models
upskill generate "write git commits" --model sonnet --eval-model haiku
```

### 2. Evaluate a Skill

```bash
# Basic evaluation
upskill eval ./skills/my-skill/

# Multi-model benchmarking
upskill eval ./skills/my-skill/ -m haiku -m sonnet --runs 5

# Against a local model
upskill eval ./skills/my-skill/ -m "unsloth/GLM-4.7-Flash" --base-url http://localhost:8080/v1
```

### 3. List and View Results

```bash
upskill list                         # Show all skills
upskill list -v                      # Include skill preview
upskill runs                         # View performance plots
upskill runs --csv ./results.csv     # Export to CSV
```

## Skill Directory Structure

```
./skills/{skill-name}/
+-- SKILL.md              # Main instructions (the "brain" of the skill)
+-- skill_meta.json        # Metadata (created_at, description)
+-- references/            # Supporting documents (optional)
+-- scripts/               # Executable scripts (optional)
```

## Python API

```python
from upskill import generate_skill, evaluate_skill, Config

# Load configuration
config = Config.load()

# Generate a skill using a teacher model
skill = await generate_skill(
    "parse and generate S-expressions for spreadsheet skills",
    model="sonnet",
    config=config
)

# Generate test cases
tests = await generate_tests(
    "parse and generate S-expressions for spreadsheet skills"
)

# Evaluate the skill on a student model
results = await evaluate_skill(
    skill, tests,
    model="haiku",
    config=config
)

print(f"Skill Lift: {results.skill_lift:.0%}")
print(f"Token Savings: {results.token_savings:.0%}")
print(f"Beneficial: {results.is_beneficial}")
```

## Test Cases Format

```json
[
  {
    "input": "Generate a project-scope skill S-expression",
    "expected": {"contains": ["define-skill", "inputs", "outputs", "compute"]}
  },
  {
    "input": "Create wiring for 3 connected skills",
    "expected": {"contains": ["define-wiring", "connect", "->"]}
  }
]
```

## Evaluation Metrics

| Metric | Description | Threshold |
|--------|-------------|-----------|
| `skill_lift` | Success rate improvement over baseline | > 5% |
| `token_savings` | Reduction in tokens used | > 20% |
| `is_beneficial` | Combined assessment | lift > 5% OR (lift >= 0 AND savings > 20%) |
| `total_tokens` | Total tokens consumed | Lower is better |
| `llm_time_ms` | Time spent in model inference | Lower is better |

## Configuration

### ~/.config/upskill/config.yaml

```yaml
model: sonnet                    # Default generation model
eval_model: haiku               # Default evaluation model
skills_dir: ./skills            # Where to save skills
runs_dir: ./runs                # Where to save run logs
max_refine_attempts: 3          # Refinement iterations
```

## Why Upskill Matters for NeoExcelPPT

In our project, Upskill enables us to:

1. **Generate S-Expression Skills** - Use a teacher model to create proper skill definitions in our DSL
2. **Train Smaller Models** - Distill the ability to generate/interpret S-expressions into local models
3. **Evaluate Quality** - Automatically measure if generated S-expressions are valid and useful
4. **Iterate Rapidly** - The generate-evaluate-refine loop tightens the feedback cycle
5. **Reduce Costs** - Once a small model learns the skill, cloud API costs drop dramatically

### Our Workflow

```
[Claude Opus / Sonnet]  --upskill generate-->  [SKILL.md: S-Expr Generation]
                                                       |
                                                       v
[SmolLM / Haiku]  <--loads skill--  [./skills/sexpr-generator/SKILL.md]
                                                       |
                                                       v
                                              [upskill eval]
                                              Does SmolLM generate valid S-exprs?
                                              skill_lift: 47%  token_savings: 62%
                                              is_beneficial: true
```

## Dependencies

- `fast-agent-mcp` (>=0.4.41): Agent runtime and MCP support
- `pydantic` (>=2.0): Data validation and models
- `click` (>=8.1): CLI framework
- `rich` (>=13.0): Terminal output formatting
- `pyyaml` (>=6.0): Configuration parsing

## Model Naming Convention

```
<provider>.<model>.<reasoning_effort?>
```

Examples:
- `sonnet`, `haiku`, `opus` - Anthropic aliases
- `anthropic.claude-sonnet-4-20250514` - Full Anthropic name
- `openai.gpt-4.1` - OpenAI model
- `generic.llama3.2:latest` - Local Ollama model

## Local Model Support

```bash
# Via Ollama
ollama serve
upskill eval ./skills/my-skill/ --model llama3.2:latest \
  --base-url http://localhost:11434/v1

# Via llama.cpp
./llama-server -m model.gguf --port 8080
upskill eval ./skills/my-skill/ --model my-model \
  --base-url http://localhost:8080/v1
```
