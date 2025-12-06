defmodule Mix.Tasks.StepLinter.Rules.StepTooLong do
  @moduledoc """
  Detects step definitions that are too long.

  Long step definitions often indicate that the step is doing too much.
  Steps should be simple and focused on a single action or assertion.

  ## Why This Matters

  - **Readability**: Long steps are harder to understand
  - **Maintainability**: Large steps are harder to modify
  - **Reusability**: Complex steps are rarely reusable
  - **Debugging**: Hard to pinpoint failures in long steps

  ## How to Fix

  Extract helper functions for complex logic:

  ### Bad (too long):
  ```elixir
  step "I create a complete user profile", context do
    user = create_user(%{name: "Test"})
    profile = create_profile(user)
    settings = create_settings(user)
    preferences = create_preferences(user)
    # ... 20 more lines ...
    {:ok, context}
  end
  ```

  ### Good (extracted helpers):
  ```elixir
  step "I create a complete user profile", context do
    user = create_user_with_full_profile()
    {:ok, Map.put(context, :user, user)}
  end

  defp create_user_with_full_profile do
    user = create_user(%{name: "Test"})
    create_profile(user)
    create_settings(user)
    create_preferences(user)
    user
  end
  ```

  ## Configuration

  Default maximum lines: 25
  """
  use Boundary, classify_to: JargaApp

  @behaviour Mix.Tasks.StepLinter.Rule

  @max_lines 25

  @impl true
  def name, do: "step_too_long"

  @impl true
  def description do
    "Detects step definitions over #{@max_lines} lines - extract helper functions"
  end

  @impl true
  def check(%{body_ast: nil}), do: []

  def check(%{body_ast: body_ast, pattern: pattern, line: step_line}) do
    line_count = count_lines(body_ast)

    if line_count > @max_lines do
      [
        %{
          rule: name(),
          message:
            "Step \"#{truncate(pattern, 50)}\" is #{line_count} lines (max: #{@max_lines}). " <>
              "Consider extracting helper functions to reduce complexity.",
          severity: :warning,
          line: step_line,
          details: %{
            line_count: line_count,
            max_lines: @max_lines,
            pattern: pattern
          }
        }
      ]
    else
      []
    end
  end

  # Count lines by converting AST to string and counting newlines
  defp count_lines(ast) do
    ast
    |> Macro.to_string()
    |> String.split("\n")
    |> length()
  end

  defp truncate(string, max_length) when byte_size(string) <= max_length, do: string

  defp truncate(string, max_length) do
    String.slice(string, 0, max_length - 3) <> "..."
  end
end
