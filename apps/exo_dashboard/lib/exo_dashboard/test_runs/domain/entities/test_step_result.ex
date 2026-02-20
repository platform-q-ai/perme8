defmodule ExoDashboard.TestRuns.Domain.Entities.TestStepResult do
  @moduledoc """
  Pure domain entity representing the result of a single test step.

  Status values: :passed, :failed, :pending, :skipped, :undefined, :ambiguous
  """

  @type status :: :passed | :failed | :pending | :skipped | :undefined | :ambiguous

  @type t :: %__MODULE__{
          test_step_id: String.t() | nil,
          status: status() | nil,
          duration_ms: non_neg_integer() | nil,
          error_message: String.t() | nil,
          exception: map() | nil
        }

  defstruct [
    :test_step_id,
    :status,
    :duration_ms,
    :error_message,
    :exception
  ]

  @doc "Creates a new TestStepResult from a keyword list or map."
  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs), do: struct(__MODULE__, attrs)
  def new(attrs) when is_map(attrs), do: struct(__MODULE__, attrs)
end
