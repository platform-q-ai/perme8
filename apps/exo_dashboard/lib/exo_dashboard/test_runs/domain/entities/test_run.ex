defmodule ExoDashboard.TestRuns.Domain.Entities.TestRun do
  @moduledoc """
  Pure domain entity representing a test run session.

  Tracks the lifecycle of a test execution from pending -> running -> passed/failed.
  """

  @type status :: :pending | :running | :passed | :failed

  @type t :: %__MODULE__{
          id: String.t() | nil,
          config_path: String.t() | nil,
          status: status(),
          scope: tuple() | nil,
          started_at: DateTime.t() | nil,
          finished_at: DateTime.t() | nil,
          test_cases: list(),
          progress: map()
        }

  defstruct [
    :id,
    :config_path,
    :scope,
    :started_at,
    :finished_at,
    status: :pending,
    test_cases: [],
    progress: %{total: 0, passed: 0, failed: 0, skipped: 0, pending: 0}
  ]

  @doc "Creates a new TestRun from a keyword list or map."
  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs), do: struct(__MODULE__, attrs)
  def new(attrs) when is_map(attrs), do: struct(__MODULE__, attrs)

  @doc "Transitions the run to :running status with a timestamp."
  @spec start(t()) :: t()
  def start(%__MODULE__{} = run) do
    %{run | status: :running, started_at: DateTime.utc_now()}
  end

  @doc "Transitions the run to a final status (:passed or :failed) with a timestamp."
  @spec finish(t(), :passed | :failed) :: t()
  def finish(%__MODULE__{} = run, status) when status in [:passed, :failed] do
    %{run | status: status, finished_at: DateTime.utc_now()}
  end
end
