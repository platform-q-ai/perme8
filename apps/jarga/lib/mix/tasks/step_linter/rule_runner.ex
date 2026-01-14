defmodule Mix.Tasks.StepLinter.RuleRunner do
  @moduledoc """
  Runs linting rules against step definitions.

  This module manages the collection of available rules and executes
  them against parsed step definitions.
  """
  use Boundary, top_level?: true

  alias Mix.Tasks.StepLinter.Rules.{
    FileTooLong,
    NoBranching,
    NoSleepCalls,
    NoStubs,
    StepTooLong,
    UnusedContextParameter,
    UseLiveviewTesting
  }

  # Rules that check individual steps
  @step_rules [
    NoBranching,
    NoSleepCalls,
    NoStubs,
    StepTooLong,
    UnusedContextParameter,
    UseLiveviewTesting
  ]

  # Rules that check at the file level
  @file_rules [
    FileTooLong
  ]

  @doc """
  Runs all applicable rules against step definitions from a file.

  Options:
  - `selected_rule` - If provided, only run the rule with this name
  - `file_line_count` - Total lines in the file (for file-level rules)
  """
  @spec run_rules(String.t(), [map()], String.t() | nil, keyword()) :: [map()]
  def run_rules(file, step_definitions, selected_rule \\ nil, opts \\ []) do
    step_rules = filter_rules(@step_rules, selected_rule)
    file_rules = filter_rules(@file_rules, selected_rule)
    file_line_count = Keyword.get(opts, :file_line_count, 0)

    # Run step-level rules
    step_issues =
      step_definitions
      |> Enum.flat_map(fn step_def ->
        step_rules
        |> Enum.flat_map(fn rule -> rule.check(step_def) end)
        |> Enum.map(fn issue ->
          issue
          |> Map.put(:file, file)
          |> Map.put_new(:line, step_def.line)
        end)
      end)

    # Run file-level rules
    file_issues =
      file_rules
      |> Enum.flat_map(fn rule ->
        rule.check(%{file: file, file_line_count: file_line_count})
      end)
      |> Enum.map(fn issue -> Map.put(issue, :file, file) end)

    step_issues ++ file_issues
  end

  @doc """
  Returns all available rules.
  """
  @spec available_rules() :: [module()]
  def available_rules, do: @step_rules ++ @file_rules

  defp filter_rules(rules, nil), do: rules

  defp filter_rules(rules, rule_name) do
    Enum.filter(rules, fn rule -> rule.name() == rule_name end)
  end
end
