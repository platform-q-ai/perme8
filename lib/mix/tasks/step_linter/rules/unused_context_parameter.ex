defmodule Mix.Tasks.StepLinter.Rules.UnusedContextParameter do
  @moduledoc """
  Detects step definitions with unused context parameters.

  When a step accepts a `context` parameter but never uses it, the parameter
  should be prefixed with underscore (`_context`) to indicate it's intentionally
  ignored.

  ## Why This Matters

  - **Code clarity**: Makes intent explicit
  - **Compiler warnings**: Elixir warns about unused variables
  - **Maintenance**: Easier to identify steps that don't need context

  ## How to Fix

  ### Bad (unused context):
  ```elixir
  step "the operation succeeds", context do
    assert true
    :ok
  end
  ```

  ### Good (underscore prefix):
  ```elixir
  step "the operation succeeds", _context do
    assert true
    :ok
  end
  ```

  ### Also Good (no parameter):
  ```elixir
  step "the operation succeeds" do
    assert true
    :ok
  end
  ```
  """
  use Boundary, classify_to: JargaApp

  @behaviour Mix.Tasks.StepLinter.Rule

  @impl true
  def name, do: "unused_context_parameter"

  @impl true
  def description do
    "Detects context parameters that are never used - should use _context instead"
  end

  @impl true
  def check(%{body_ast: nil}), do: []

  def check(%{ast: ast, body_ast: body_ast, pattern: pattern, line: step_line}) do
    context_param = extract_context_param(ast)

    cond do
      # No context parameter or already underscored
      context_param == nil ->
        []

      String.starts_with?(Atom.to_string(context_param), "_") ->
        []

      # Check if context is used in the body
      context_used?(body_ast, context_param) ->
        []

      true ->
        [
          %{
            rule: name(),
            message:
              "Step \"#{truncate(pattern, 50)}\" has unused context parameter '#{context_param}'. " <>
                "Use '_context' or '_' if the context is not needed.",
            severity: :warning,
            line: step_line,
            details: %{
              parameter: context_param,
              pattern: pattern
            }
          }
        ]
    end
  end

  # Extract the context parameter name from the step definition AST
  # Handles: step "pattern", context do ... end
  # Handles: step "pattern", %{args: [x]} = context do ... end
  defp extract_context_param({:step, _, [_pattern | rest]}) do
    case rest do
      # step "pattern", context do ... end
      [{context_var, _, nil}, [do: _body]] when is_atom(context_var) ->
        context_var

      # step "pattern", %{} = context do ... end
      [{:=, _, [_match, {context_var, _, nil}]}, [do: _body]] when is_atom(context_var) ->
        context_var

      # step "pattern", context = %{} do ... end
      [{:=, _, [{context_var, _, nil}, _match]}, [do: _body]] when is_atom(context_var) ->
        context_var

      # step "pattern" do ... end (no context param)
      [[do: _body]] ->
        nil

      _ ->
        nil
    end
  end

  defp extract_context_param(_), do: nil

  # Check if the context variable is used in the body
  defp context_used?(body_ast, context_param) do
    {_ast, used} =
      Macro.prewalk(body_ast, false, fn
        {^context_param, _, atom_ctx} = node, _acc when is_atom(atom_ctx) ->
          {node, true}

        node, acc ->
          {node, acc}
      end)

    used
  end

  defp truncate(string, max_length) when byte_size(string) <= max_length, do: string

  defp truncate(string, max_length) do
    String.slice(string, 0, max_length - 3) <> "..."
  end
end
