defmodule ExoDashboard.TestRuns.Domain.Entities.TestCaseResult do
  @moduledoc """
  Pure domain entity representing the result of a test case (scenario).

  Aggregates step results and derives an overall status.
  """

  alias ExoDashboard.TestRuns.Domain.Entities.TestStepResult
  alias ExoDashboard.TestRuns.Domain.Policies.StatusPolicy

  @type t :: %__MODULE__{
          pickle_id: String.t() | nil,
          test_case_id: String.t() | nil,
          test_case_started_id: String.t() | nil,
          status: atom(),
          step_results: [TestStepResult.t()],
          duration: non_neg_integer() | nil,
          feature_uri: String.t() | nil,
          scenario_name: String.t() | nil,
          attempt: non_neg_integer() | nil
        }

  defstruct [
    :pickle_id,
    :test_case_id,
    :test_case_started_id,
    :duration,
    :feature_uri,
    :scenario_name,
    :attempt,
    status: :pending,
    step_results: []
  ]

  @doc "Creates a new TestCaseResult from a keyword list or map."
  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs), do: struct(__MODULE__, attrs)
  def new(attrs) when is_map(attrs), do: struct(__MODULE__, attrs)

  @doc "Appends a step result and recomputes aggregate status."
  @spec add_step_result(t(), TestStepResult.t()) :: t()
  def add_step_result(%__MODULE__{} = result, %TestStepResult{} = step) do
    new_steps = result.step_results ++ [step]
    statuses = Enum.map(new_steps, & &1.status)
    new_status = StatusPolicy.aggregate_status(statuses)

    %{result | step_results: new_steps, status: new_status}
  end
end
