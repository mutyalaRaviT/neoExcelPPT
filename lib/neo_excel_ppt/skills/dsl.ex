defmodule NeoExcelPPT.Skills.DSL do
  @moduledoc """
  S-Expression DSL for defining Skills.

  ## DSL Specification

  ### Basic Structure
  ```
  (define-skill :skill-id
    (inputs :channel1 :channel2)
    (outputs :output1 :output2)
    (state {:key value})
    (compute
      (expression)))
  ```

  ### Expressions
  - `(get state :key)` - Get value from state
  - `(get input :channel)` - Get value from input
  - `(set :key value)` - Set state key
  - `(emit :channel value)` - Emit to output channel
  - `(+ a b)` / `(- a b)` / `(* a b)` / `(/ a b)` - Arithmetic
  - `(sum list)` - Sum a list
  - `(count list)` - Count items
  - `(map fn list)` - Map over list
  - `(filter pred list)` - Filter list
  - `(let [bindings] body)` - Local bindings
  - `(if cond then else)` - Conditional
  - `(pipe value fns...)` - Pipeline

  ### Wiring Definition
  ```
  (define-wiring
    (connect :skill1:output -> :skill2:input)
    (connect :skill2:output -> :skill3:input))
  ```

  ## Examples

  ```
  (define-skill :project-scope
    (inputs :file-counts)
    (outputs :total-files :component-breakdown)
    (state {:simple 0 :medium 0 :complex 0})
    (compute
      (let [files (get input :file-counts)
            simple (get files :simple)
            medium (get files :medium)
            complex (get files :complex)
            total (+ simple medium complex)]
        (set :simple simple)
        (set :medium medium)
        (set :complex complex)
        (emit :total-files total)
        (emit :component-breakdown
          {:simple simple :medium medium :complex complex}))))
  ```
  """

  @type ast :: atom() | number() | String.t() | list() | map()
  @type parse_result :: {:ok, ast()} | {:error, String.t()}

  # ============================================================================
  # Parsing S-expressions
  # ============================================================================

  @doc """
  Parse an S-expression string into an AST.
  """
  @spec parse(String.t()) :: parse_result()
  def parse(input) when is_binary(input) do
    input
    |> String.trim()
    |> tokenize()
    |> parse_tokens()
  end

  @doc """
  Tokenize input string into tokens.
  """
  def tokenize(input) do
    # Simple tokenizer - splits on parens and whitespace
    input
    |> String.replace("(", " ( ")
    |> String.replace(")", " ) ")
    |> String.split(~r/\s+/, trim: true)
  end

  @doc """
  Parse tokens into AST.
  """
  def parse_tokens([]), do: {:error, "Empty input"}
  def parse_tokens(tokens) do
    case do_parse(tokens) do
      {:ok, ast, []} -> {:ok, ast}
      {:ok, ast, _rest} -> {:ok, ast}  # Allow trailing content
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_parse([]), do: {:error, "Unexpected end of input"}

  defp do_parse(["(" | rest]) do
    parse_list(rest, [])
  end

  defp do_parse([")" | _rest]) do
    {:error, "Unexpected closing parenthesis"}
  end

  defp do_parse([token | rest]) do
    {:ok, parse_atom(token), rest}
  end

  defp parse_list([")" | rest], acc) do
    {:ok, Enum.reverse(acc), rest}
  end

  defp parse_list([], _acc) do
    {:error, "Unclosed parenthesis"}
  end

  defp parse_list(tokens, acc) do
    case do_parse(tokens) do
      {:ok, element, rest} ->
        parse_list(rest, [element | acc])
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_atom(token) do
    cond do
      # Keywords (:keyword)
      String.starts_with?(token, ":") ->
        token |> String.slice(1..-1//1) |> String.to_atom()

      # Numbers
      Regex.match?(~r/^-?\d+(\.\d+)?$/, token) ->
        if String.contains?(token, ".") do
          String.to_float(token)
        else
          String.to_integer(token)
        end

      # Strings (quoted)
      String.starts_with?(token, "\"") && String.ends_with?(token, "\"") ->
        String.slice(token, 1..-2//1)

      # Booleans
      token == "true" -> true
      token == "false" -> false
      token == "nil" -> nil

      # Symbols/identifiers
      true ->
        String.to_atom(token)
    end
  end

  # ============================================================================
  # Converting AST to Elixir Skill definitions
  # ============================================================================

  @doc """
  Convert a skill AST to a skill definition map.
  """
  @spec ast_to_skill(ast()) :: {:ok, map()} | {:error, String.t()}
  def ast_to_skill([:"define-skill", skill_id | body]) when is_atom(skill_id) do
    skill = %{
      id: skill_id,
      inputs: [],
      outputs: [],
      state: %{},
      compute: nil
    }

    skill = Enum.reduce(body, skill, fn
      [:inputs | channels], acc ->
        %{acc | inputs: channels}

      [:outputs | channels], acc ->
        %{acc | outputs: channels}

      [:state, initial_state], acc when is_map(initial_state) ->
        %{acc | state: initial_state}

      [:state | pairs], acc ->
        state = pairs_to_map(pairs)
        %{acc | state: state}

      [:compute | expr], acc ->
        %{acc | compute: expr}

      _, acc ->
        acc
    end)

    {:ok, skill}
  end

  def ast_to_skill(_), do: {:error, "Invalid skill definition"}

  defp pairs_to_map(pairs) do
    pairs
    |> Enum.chunk_every(2)
    |> Enum.reduce(%{}, fn
      [key, value], acc when is_atom(key) -> Map.put(acc, key, value)
      _, acc -> acc
    end)
  end

  @doc """
  Convert a wiring AST to a wiring map.
  """
  @spec ast_to_wiring(ast()) :: {:ok, map()} | {:error, String.t()}
  def ast_to_wiring([:"define-wiring" | connections]) do
    wiring = Enum.reduce(connections, %{}, fn
      [:connect, source, :"->" | targets], acc ->
        {src_skill, src_channel} = parse_channel_ref(source)
        targets = Enum.map(targets, &parse_channel_ref/1)
        key = {src_skill, src_channel}
        Map.update(acc, key, targets, &(&1 ++ targets))

      _, acc ->
        acc
    end)

    {:ok, wiring}
  end

  def ast_to_wiring(_), do: {:error, "Invalid wiring definition"}

  defp parse_channel_ref(ref) when is_atom(ref) do
    ref
    |> Atom.to_string()
    |> String.split(":")
    |> case do
      [skill, channel] -> {String.to_atom(skill), String.to_atom(channel)}
      _ -> {ref, ref}
    end
  end

  # ============================================================================
  # Converting Skills to S-expression AST
  # ============================================================================

  @doc """
  Convert a skill definition map to AST.
  """
  @spec skill_to_ast(map()) :: ast()
  def skill_to_ast(%{id: id, inputs: inputs, outputs: outputs, state: state}) do
    [
      :"define-skill", id,
      [:inputs | inputs],
      [:outputs | outputs],
      [:state, state]
    ]
  end

  @doc """
  Convert a wiring map to AST.
  """
  @spec wiring_to_ast(map()) :: ast()
  def wiring_to_ast(wiring) when is_map(wiring) do
    connections = Enum.flat_map(wiring, fn {{src_skill, src_channel}, targets} ->
      Enum.map(targets, fn {tgt_skill, tgt_channel} ->
        src = String.to_atom("#{src_skill}:#{src_channel}")
        tgt = String.to_atom("#{tgt_skill}:#{tgt_channel}")
        [:connect, src, :"->", tgt]
      end)
    end)

    [:"define-wiring" | connections]
  end

  # ============================================================================
  # Serializing AST to S-expression string
  # ============================================================================

  @doc """
  Serialize AST to S-expression string.
  """
  @spec to_sexpr(ast(), keyword()) :: String.t()
  def to_sexpr(ast, opts \\ [])

  def to_sexpr(list, opts) when is_list(list) do
    indent = Keyword.get(opts, :indent, 0)
    pretty = Keyword.get(opts, :pretty, true)

    inner = list
    |> Enum.map(fn
      # Nested lists get indented
      nested when is_list(nested) and pretty ->
        "\n" <> String.duplicate("  ", indent + 1) <>
        to_sexpr(nested, Keyword.put(opts, :indent, indent + 1))
      elem ->
        to_sexpr(elem, opts)
    end)
    |> Enum.join(" ")

    "(#{inner})"
  end

  def to_sexpr(atom, _opts) when is_atom(atom) do
    case Atom.to_string(atom) do
      # Don't add : prefix for special keywords
      s when s in ["define-skill", "define-wiring", "inputs", "outputs",
                    "state", "compute", "connect", "->", "let", "if",
                    "get", "set", "emit", "sum", "count", "map", "filter",
                    "pipe", "+", "-", "*", "/"] ->
        s
      s ->
        ":#{s}"
    end
  end

  def to_sexpr(number, _opts) when is_number(number), do: to_string(number)

  def to_sexpr(string, _opts) when is_binary(string), do: "\"#{string}\""

  def to_sexpr(map, opts) when is_map(map) do
    pairs = Enum.map(map, fn {k, v} ->
      ":#{k} #{to_sexpr(v, opts)}"
    end)
    "{#{Enum.join(pairs, " ")}}"
  end

  def to_sexpr(true, _opts), do: "true"
  def to_sexpr(false, _opts), do: "false"
  def to_sexpr(nil, _opts), do: "nil"

  # ============================================================================
  # Validation
  # ============================================================================

  @doc """
  Validate a skill definition.
  """
  @spec validate_skill(map()) :: :ok | {:error, [String.t()]}
  def validate_skill(%{id: id, inputs: inputs, outputs: outputs}) do
    errors = []

    errors = if is_atom(id), do: errors, else: ["Skill ID must be an atom" | errors]
    errors = if is_list(inputs), do: errors, else: ["Inputs must be a list" | errors]
    errors = if is_list(outputs), do: errors, else: ["Outputs must be a list" | errors]

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  # ============================================================================
  # High-level API
  # ============================================================================

  @doc """
  Parse S-expression and convert to skill definition.
  """
  @spec parse_skill(String.t()) :: {:ok, map()} | {:error, String.t()}
  def parse_skill(input) do
    with {:ok, ast} <- parse(input),
         {:ok, skill} <- ast_to_skill(ast),
         :ok <- validate_skill(skill) do
      {:ok, skill}
    end
  end

  @doc """
  Convert skill definition to S-expression string.
  """
  @spec skill_to_sexpr(map()) :: String.t()
  def skill_to_sexpr(skill) do
    skill
    |> skill_to_ast()
    |> to_sexpr(pretty: true)
  end

  @doc """
  Generate sample DSL for all current skills.
  """
  @spec generate_sample_dsl() :: String.t()
  def generate_sample_dsl do
    """
    ;; Skills-Actors S-Expression DSL
    ;; Auto-generated skill definitions

    (define-skill :project-scope
      (inputs :file-counts)
      (outputs :total-files :component-breakdown)
      (state {:simple 0 :medium 0 :complex 0})
      (compute
        (let [files (get input :file-counts)]
          (emit :total-files (sum files))
          (emit :component-breakdown files))))

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

    (define-skill :activity-calculator
      (inputs :activity-update :team-assignment)
      (outputs :activity-totals :team-effort)
      (state {:activities {}})
      (compute
        (let [update (get input :activity-update)]
          (set :activities (merge (get state :activities) update))
          (emit :activity-totals (sum-values (get state :activities))))))

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

    ;; Wiring: How skills connect
    (define-wiring
      (connect :project-scope:total-files -> :component-calculator:file-count)
      (connect :project-scope:component-breakdown -> :component-calculator:breakdown)
      (connect :component-calculator:scaled-effort -> :effort-aggregator:component-effort)
      (connect :activity-calculator:activity-totals -> :effort-aggregator:activity-effort)
      (connect :buffer-calculator:buffer-days -> :effort-aggregator:buffer-days))
    """
  end
end
