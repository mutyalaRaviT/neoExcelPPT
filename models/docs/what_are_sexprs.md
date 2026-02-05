# What Are S-Expressions?

## Definition

An **S-expression** (symbolic expression, or **sexpr**) is a notation for nested list-structured data. Invented by John McCarthy in 1960 for Lisp, S-expressions represent both **code and data** using the same syntax.

```
(operator operand1 operand2 ...)
```

Everything is a list. The first element is the operator; the rest are operands. Lists can nest infinitely.

## Basic Syntax

### Atoms (Leaf Values)
```
42              ;; number
3.14            ;; float
:name           ;; keyword
"hello"         ;; string
true            ;; boolean
nil             ;; null
project-scope   ;; symbol/identifier
```

### Lists (Composite Values)
```
(+ 1 2)                          ;; => 3
(define x 42)                    ;; bind x = 42
(if (> x 10) "big" "small")     ;; conditional
(let [a 1 b 2] (+ a b))         ;; local bindings => 3
```

### Nested Lists
```
(define-skill :calculator
  (inputs :numbers)
  (outputs :result)
  (compute
    (let [nums (get input :numbers)]
      (emit :result (sum nums)))))
```

## Why S-Expressions for Our Project?

### 1. Code = Data (Homoiconicity)

S-expressions make code and data interchangeable. A skill definition IS the program:

```
;; This is data (a tree structure)
;; AND this is code (an executable specification)
(define-skill :project-scope
  (inputs :file-counts)
  (outputs :total-files)
  (compute (emit :total-files (sum (get input :file-counts)))))
```

### 2. Token Efficiency

S-expressions are extremely compact compared to JSON or XML:

**JSON (127 tokens):**
```json
{
  "type": "skill",
  "id": "project-scope",
  "inputs": ["file-counts"],
  "outputs": ["total-files"],
  "compute": {
    "type": "emit",
    "channel": "total-files",
    "value": {"type": "sum", "of": {"type": "get", "from": "input", "key": "file-counts"}}
  }
}
```

**S-Expression (23 tokens):**
```
(define-skill :project-scope
  (inputs :file-counts)
  (outputs :total-files)
  (compute (emit :total-files (sum (get input :file-counts)))))
```

That's **5.5x fewer tokens** - critical when working with LLMs where every token costs money.

### 3. Natural Composability

S-expressions nest naturally, making composition trivial:

```
;; Simple action
(db/save)

;; Composed action
(seq (validate) (db/save) (notify "Saved!"))

;; Conditional composed action
(on-click
  (if (valid?)
    (seq (db/save) (close))
    (warn "Fix errors first")))
```

### 4. Easy Parsing

An S-expression parser is ~30 lines of code:

```python
def parse(tokens):
    token = tokens.pop(0)
    if token == '(':
        result = []
        while tokens[0] != ')':
            result.append(parse(tokens))
        tokens.pop(0)  # remove ')'
        return result
    elif token == ')':
        raise SyntaxError('Unexpected )')
    else:
        return atom(token)
```

## Our S-Expression Vocabulary

### Skill Definition
```
(define-skill :id
  (inputs :channel ...)
  (outputs :channel ...)
  (state {:key value ...})
  (compute (expression)))
```

### Wiring (Connecting Skills)
```
(define-wiring
  (connect :skill1:output -> :skill2:input)
  (connect :skill2:output -> :skill3:input))
```

### Compute Expressions
```
(get state :key)           ;; read from state
(get input :channel)       ;; read from input
(set :key value)           ;; update state
(emit :channel value)      ;; send to output
(+ a b) (- a b) (* a b)   ;; arithmetic
(sum list)                 ;; aggregate
(count list)               ;; count items
(map fn list)              ;; transform
(filter pred list)         ;; select
(let [bindings] body)      ;; local variables
(if cond then else)        ;; conditional
(pipe value fns...)        ;; pipeline
```

### UI Components (Extended Vocabulary)
```
(ui/grid :id "main"
  (ui/col :field "name" :header "Name" :editable true)
  (ui/col :field "value" :header "Value" :type :number))

(ui/section :id "scope" :title "Project Scope"
  (ui/input :id "files" :type :number :bind :file-counts)
  (ui/display :id "total" :bind :total-files))
```

### UX Actions (Nestable Events)
```
(on-click (seq (db/save) (notify "Done!")))
(on-change (debounce 300 (compute-derived)))
(on-blur (validate :field (get input :value)))
```

## S-Expressions as an AST

Every S-expression IS an Abstract Syntax Tree (AST):

```
       (define-skill :project-scope ...)

                define-skill
               /            \
        :project-scope    (children)
                         /    |    \
                  (inputs)  (outputs)  (compute)
                    |          |           |
              :file-counts  :total-files  (emit ...)
                                         /        \
                                   :total-files   (sum ...)
                                                     |
                                              (get input :file-counts)
```

This tree structure maps directly to:
- **Python nested lists** for generation
- **Elixir nested lists** for runtime execution
- **ClojureScript vectors** for frontend rendering

## S-Expressions in the AI Pipeline

When an AI model generates S-expressions, it is producing **structured, parseable, composable code-as-data**:

```
[Teacher Model] --> "Generate a skill for calculating buffer days"
                         |
                         v
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

This output is:
1. **Parseable** - can be tokenized and converted to AST
2. **Validatable** - structure can be checked (has inputs? outputs? compute?)
3. **Executable** - can be interpreted directly
4. **Composable** - can be wired to other skills
5. **Evaluatable** - can be tested with upskill's evaluation framework

## Historical Context

| Language | Year | S-Expr Usage |
|----------|------|-------------|
| Lisp | 1960 | Original S-expression language |
| Scheme | 1975 | Minimalist Lisp with S-expressions |
| Emacs Lisp | 1985 | Editor configuration as S-expressions |
| Clojure | 2007 | Modern Lisp on JVM with S-expressions |
| ClojureScript | 2011 | Clojure compiling to JavaScript |
| Our DSL | 2025 | S-expressions for AI-generated skill definitions |

## Summary

S-expressions are the perfect encoding for our system because:

- **Minimal syntax** - only parentheses, atoms, and whitespace
- **Homoiconic** - code IS data, data IS code
- **Token-efficient** - 5x fewer tokens than JSON equivalents
- **Naturally composable** - nesting creates composition
- **Easy to parse** - trivial parser implementation
- **AI-friendly** - models generate them reliably
- **Universal** - same format for skills, wiring, UI, and actions
