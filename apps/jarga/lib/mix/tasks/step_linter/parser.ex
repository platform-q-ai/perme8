defmodule Mix.Tasks.StepLinter.Parser do
  @moduledoc """
  Parses step definition files and extracts step definitions.

  This module reads Elixir source files and extracts step macro calls,
  returning structured data about each step definition.
  """
  use Boundary, top_level?: true

  @doc """
  Parses a step definition file and returns a list of step definitions.

  Each step definition is a map containing:
  - `:pattern` - The step pattern string
  - `:line` - The line number where the step is defined
  - `:ast` - The full AST of the step macro call
  - `:body_ast` - The AST of the step body
  """
  @spec parse_file(String.t()) :: {:ok, [map()]} | {:error, term()}
  def parse_file(file_path) do
    with {:ok, content} <- File.read(file_path),
         {:ok, ast} <- Code.string_to_quoted(content, file: file_path, columns: true) do
      {:ok, extract_step_definitions(ast)}
    end
  end

  defp extract_step_definitions(ast) do
    {_ast, steps} = Macro.prewalk(ast, [], &find_steps/2)
    Enum.reverse(steps)
  end

  # Match step macro calls: step "pattern", context do ... end
  defp find_steps({:step, meta, [pattern | rest]} = ast, acc) when is_binary(pattern) do
    body_ast = extract_body(rest)

    step_def = %{
      pattern: pattern,
      line: Keyword.get(meta, :line, 0),
      ast: ast,
      body_ast: body_ast
    }

    {ast, [step_def | acc]}
  end

  # Match step macro with pattern as first arg (could be a variable reference)
  defp find_steps({:step, meta, [{:<<>>, _, _} = pattern | rest]} = ast, acc) do
    body_ast = extract_body(rest)

    step_def = %{
      pattern: Macro.to_string(pattern),
      line: Keyword.get(meta, :line, 0),
      ast: ast,
      body_ast: body_ast
    }

    {ast, [step_def | acc]}
  end

  defp find_steps(ast, acc), do: {ast, acc}

  # Extract the body from the step arguments
  # Pattern: step "...", context do ... end
  # The body is in the do block
  defp extract_body(args) do
    case args do
      # Pattern: step "pattern", context do ... end
      # Also handles: step "pattern", %{} = context do ... end
      [_context, [do: body]] ->
        body

      # Pattern with keyword list containing do block
      [[do: body] | _] ->
        body

      # Just a do block
      [do: body] ->
        body

      _ ->
        nil
    end
  end
end
