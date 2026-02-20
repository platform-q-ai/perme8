defmodule ExoDashboard.TestRuns do
  @moduledoc """
  Public API facade for the TestRuns context.

  Delegates to use cases and infrastructure for test run management.
  """

  use Boundary,
    top_level?: true,
    deps: [ExoDashboard.Features],
    exports: [
      Domain.Entities.TestRun,
      Domain.Entities.TestCaseResult,
      Domain.Entities.TestStepResult
    ]

  alias ExoDashboard.TestRuns.Infrastructure.ResultStore

  @doc "Retrieves a test run by ID."
  def get_run(run_id) do
    ResultStore.get_run(run_id)
  end

  @doc "Lists all stored test runs."
  def list_runs do
    ResultStore.list_runs()
  end

  @doc "Gets all test case results for a given run."
  def get_results(run_id) do
    ResultStore.get_test_case_results(run_id)
  end
end
