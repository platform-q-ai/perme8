defmodule Mix.Tasks.StepLinter.Rule do
  @moduledoc """
  Behaviour for step linter rules.

  Implement this behaviour to create custom linting rules for step definitions.

  ## Example

      defmodule Mix.Tasks.StepLinter.Rules.MyRule do
        @behaviour Mix.Tasks.StepLinter.Rule

        @impl true
        def name, do: "my_rule"

        @impl true
        def description, do: "Checks for something specific"

        @impl true
        def check(step_definition) do
          # Return list of issues found
          []
        end
      end
  """
  use Boundary, classify_to: JargaApp

  @type step_definition :: %{
          pattern: String.t(),
          line: non_neg_integer(),
          ast: Macro.t(),
          body_ast: Macro.t()
        }

  @type issue :: %{
          rule: String.t(),
          message: String.t(),
          severity: :error | :warning | :info,
          line: non_neg_integer(),
          details: map()
        }

  @doc "Returns the unique identifier for this rule"
  @callback name() :: String.t()

  @doc "Returns a human-readable description of what this rule checks"
  @callback description() :: String.t()

  @doc """
  Checks a step definition for issues.

  Receives a step definition map containing:
  - `:pattern` - The step pattern string (e.g., "I click the {string} button")
  - `:line` - The line number where the step is defined
  - `:ast` - The full AST of the step macro call
  - `:body_ast` - The AST of just the step body (the do block)

  Returns a list of issues found, or an empty list if the step passes.
  """
  @callback check(step_definition()) :: [issue()]
end
