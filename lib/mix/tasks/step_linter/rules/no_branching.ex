defmodule Mix.Tasks.StepLinter.Rules.NoBranching do
  @moduledoc """
  Detects branching logic in step definitions.

  Step definitions should be simple and deterministic. When a step contains
  branching logic (if/case/cond), it often indicates that:

  1. The step is trying to handle multiple contexts/scenarios
  2. The behavior depends on hidden state that makes tests unpredictable
  3. The step should be split into multiple, more specific steps

  ## Why This Matters

  Branching in step definitions leads to:
  - **Flaky tests**: Different behavior based on context state
  - **Silent failures**: Some branches may not assert properly
  - **Hidden logic**: Test behavior is not visible in the feature file

  ## How to Fix

  Instead of branching, create separate step definitions for each context:

  ### Bad (direct context branching):
  ```elixir
  step "I confirm deletion", context do
    cond do
      context[:workspace] -> delete_workspace(context)
      context[:document] -> delete_document(context)
      true -> flunk("No deletion context")
    end
  end
  ```

  ### Bad (indirect context branching via extracted variable):
  ```elixir
  step "the agent selector should list {string}", %{args: [name]} = context do
    view = context[:view]

    if view do
      html = render(view)
      assert html =~ name
      {:ok, Map.put(context, :last_html, html)}
    else
      {:ok, context}  # Silent no-op!
    end
  end
  ```

  ### Good (separate steps):
  ```elixir
  step "I confirm workspace deletion", context do
    delete_workspace(context)
  end

  step "I confirm document deletion", context do
    delete_document(context)
  end
  ```

  ### Good (require context with pattern matching):
  ```elixir
  step "the agent selector should list {string}", %{args: [name], view: view} = context do
    html = render(view)
    assert html =~ name
    {:ok, Map.put(context, :last_html, html)}
  end
  ```

  ### Good (fail fast if context is missing):
  ```elixir
  step "the agent selector should list {string}", %{args: [name]} = context do
    view = context[:view] || raise "No view in context"
    html = render(view)
    assert html =~ name
    {:ok, Map.put(context, :last_html, html)}
  end
  ```

  ## Detection

  This rule detects both:
  1. **Direct context access**: `if context[:view] do`
  2. **Indirect access via variables**: `view = context[:view]; if view do`

  ## Exceptions

  Some branching is acceptable:
  - `case` on function return values (e.g., `{:ok, result} | {:error, reason}`)
  - `if` for optional cleanup or logging
  - Pattern matching in function heads
  - `with` statements (pattern matching on function results)

  This rule focuses on context-dependent branching that changes step behavior.
  """
  use Boundary, classify_to: JargaApp

  @behaviour Mix.Tasks.StepLinter.Rule

  @branching_constructs [:if, :unless, :case, :cond, :with]

  @impl true
  def name, do: "no_branching"

  @impl true
  def description do
    "No branching allowed in step definitions - scenarios requiring different contexts should use different step definitions"
  end

  @impl true
  def check(%{body_ast: nil}), do: []

  def check(%{body_ast: body_ast, pattern: pattern, line: step_line}) do
    branches = find_branches(body_ast, step_line)

    # Filter to only context-dependent branches (accessing context map)
    problematic_branches = Enum.filter(branches, &context_dependent?(&1, body_ast))

    if Enum.empty?(problematic_branches) do
      []
    else
      branch_summary =
        Enum.map_join(problematic_branches, ", ", fn b -> "#{b.type} at line #{b.line}" end)

      [
        %{
          rule: name(),
          message:
            "Step \"#{truncate(pattern, 50)}\" contains context-dependent branching (#{branch_summary}). " <>
              "Scenarios requiring different contexts should use different step definitions.",
          severity: :error,
          line: step_line,
          details: %{
            branches: problematic_branches,
            pattern: pattern
          }
        }
      ]
    end
  end

  # Find all branching constructs in the AST
  defp find_branches(ast, base_line) do
    {_ast, branches} = Macro.prewalk(ast, [], &find_branch_nodes(&1, &2, base_line))
    branches
  end

  defp find_branch_nodes({construct, meta, args} = ast, acc, base_line)
       when construct in @branching_constructs and is_list(args) do
    line = Keyword.get(meta, :line, base_line)

    branch = %{
      type: construct,
      line: line,
      ast: ast,
      condition_ast: extract_condition(construct, args)
    }

    {ast, [branch | acc]}
  end

  defp find_branch_nodes(ast, acc, _base_line), do: {ast, acc}

  # Extract the condition from different branching constructs
  defp extract_condition(:if, [condition | _]), do: condition
  defp extract_condition(:unless, [condition | _]), do: condition
  defp extract_condition(:case, [subject | _]), do: subject
  defp extract_condition(:cond, _), do: nil
  defp extract_condition(:with, args), do: List.first(args)
  defp extract_condition(_, _), do: nil

  # Check if a branch depends on the context map
  # This is the key heuristic: we want to flag branches that check context[:key]
  # or variables that were assigned from context[:key]
  defp context_dependent?(branch, full_ast) do
    context_derived_vars = find_context_derived_variables(full_ast)
    function_result_vars = find_function_result_variables(full_ast)

    check_branch_dependency(branch, context_derived_vars, function_result_vars)
  end

  defp check_branch_dependency(
         %{type: :cond, ast: ast},
         context_derived_vars,
         _function_result_vars
       ) do
    check_cond_branches(ast, context_derived_vars)
  end

  defp check_branch_dependency(
         %{type: :case, condition_ast: condition},
         context_derived_vars,
         function_result_vars
       ) do
    not function_call_result?(condition, function_result_vars) and
      (context_access?(condition) or uses_context_derived_var?(condition, context_derived_vars))
  end

  defp check_branch_dependency(
         %{type: type, condition_ast: condition},
         context_derived_vars,
         _function_result_vars
       )
       when type in [:if, :unless] do
    context_access?(condition) or uses_context_derived_var?(condition, context_derived_vars)
  end

  defp check_branch_dependency(%{type: :with}, _context_derived_vars, _function_result_vars),
    do: false

  defp check_branch_dependency(_branch, _context_derived_vars, _function_result_vars), do: false

  # Find variables that are assigned from function calls or pipes
  # These are OK to branch on (e.g., result = render_submit(...) or result = x |> func())
  # Even if the pipe starts with context access, the RESULT is a function call result
  defp find_function_result_variables(ast) do
    {_ast, vars} =
      Macro.prewalk(ast, MapSet.new(), fn
        # var = expression - check if the expression produces a function result
        {:=, _, [{var_name, _, nil}, call_ast]} = node, acc when is_atom(var_name) ->
          if produces_function_result?(call_ast) do
            {node, MapSet.put(acc, var_name)}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    vars
  end

  # Check if an expression produces a function result (not just reads context)
  # A pipe expression produces a function result even if it starts with context access
  # e.g., context[:view] |> form(...) |> render_submit() -> produces a function result
  defp produces_function_result?({:|>, _, [_left, right]}), do: produces_function_result?(right)
  defp produces_function_result?({{:., _, _}, _, _}), do: true

  defp produces_function_result?({name, _, args}) when is_atom(name) and is_list(args) do
    # Function call - but exclude simple context access operators
    name not in [:get]
  end

  defp produces_function_result?(_), do: false

  # Check if AST is a function call or pipe expression (for the case condition check)
  defp function_call_or_pipe?({{:., _, _}, _, _}), do: true
  defp function_call_or_pipe?({:|>, _, _}), do: true
  defp function_call_or_pipe?({name, _, args}) when is_atom(name) and is_list(args), do: true
  defp function_call_or_pipe?(_), do: false

  # Check if the condition is a function call result or variable holding one
  defp function_call_result?(nil, _vars), do: false

  defp function_call_result?(ast, function_result_vars) do
    # Direct function call or pipe
    # Variable that holds function result
    function_call_or_pipe?(ast) or
      (match?({var_name, _, nil} when is_atom(var_name), ast) and
         MapSet.member?(function_result_vars, elem(ast, 0)))
  end

  # Find all variables that are assigned from context access
  # e.g., view = context[:view], user = context[:user], etc.
  defp find_context_derived_variables(ast) do
    {_ast, vars} =
      Macro.prewalk(ast, MapSet.new(), fn
        # var = context[:key]
        {:=, _, [{var_name, _, nil}, access_ast]} = node, acc when is_atom(var_name) ->
          if context_access?(access_ast) do
            {node, MapSet.put(acc, var_name)}
          else
            {node, acc}
          end

        # context[:key] = var (reverse assignment, less common but possible)
        {:=, _, [access_ast, {var_name, _, nil}]} = node, acc when is_atom(var_name) ->
          if context_access?(access_ast) do
            {node, MapSet.put(acc, var_name)}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    vars
  end

  # Check if an AST node uses any of the context-derived variables
  defp uses_context_derived_var?(nil, _vars), do: false
  defp uses_context_derived_var?(_ast, vars) when map_size(vars) == 0, do: false

  defp uses_context_derived_var?(ast, context_derived_vars) do
    {_ast, found} =
      Macro.prewalk(ast, false, fn
        # Match variable references (not assignments)
        {var_name, _, atom_ctx} = node, _acc
        when is_atom(var_name) and is_atom(atom_ctx) and atom_ctx != nil ->
          {node, false}

        # Match plain variable reference
        {var_name, _, nil} = node, acc when is_atom(var_name) ->
          if MapSet.member?(context_derived_vars, var_name) do
            {node, true}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    found
  end

  # Check if cond branches access context or use context-derived variables
  defp check_cond_branches({:cond, _, [[do: branches]]}, context_derived_vars) do
    Enum.any?(branches, fn {:->, _, [[condition], _body]} ->
      context_access?(condition) or uses_context_derived_var?(condition, context_derived_vars)
    end)
  end

  defp check_cond_branches(_, _context_derived_vars), do: false

  # Check if an AST node accesses context[:key] or context.key
  defp context_access?(nil), do: false

  defp context_access?(ast) do
    {_ast, found} =
      Macro.prewalk(ast, false, fn
        # context[:key] pattern
        {{:., _, [Access, :get]}, _, [{:context, _, _}, _key]} = node, _acc ->
          {node, true}

        # context[:key] via Access.get
        {:get_in, _, [{:context, _, _}, _keys]} = node, _acc ->
          {node, true}

        # Access bracket syntax on context
        {{:., _, [{:context, _, _}, :__struct__]}, _, _} = node, acc ->
          {node, acc}

        # context[:key] - direct bracket access
        {Access, :get, [{:context, _, _}, _key]} = node, _acc ->
          {node, true}

        # Check for Access.get(context, ...) calls
        {{:., _, [{:__aliases__, _, [:Access]}, :get]}, _, [{:context, _, _} | _]} = node, _acc ->
          {node, true}

        # Map.get(context, ...) or Map.has_key?(context, ...)
        {{:., _, [{:__aliases__, _, [:Map]}, func]}, _, [{:context, _, _} | _]} = node, _acc
        when func in [:get, :has_key?, :fetch, :fetch!] ->
          {node, true}

        # context.key pattern
        {{:., _, [{:context, _, _}, _key]}, _, _} = node, _acc ->
          {node, true}

        # context[:key] - bracket access via Access behaviour
        {{:., _, [Access, :get]}, _, [{:context, _, _} | _]} = node, _acc ->
          {node, true}

        node, acc ->
          {node, acc}
      end)

    found
  end

  defp truncate(string, max_length) when byte_size(string) <= max_length, do: string

  defp truncate(string, max_length) do
    String.slice(string, 0, max_length - 3) <> "..."
  end
end
