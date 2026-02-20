defmodule ExoDashboard.TestRuns.Domain.Policies.StatusPolicy do
  @moduledoc """
  Pure policy for aggregating step/test case statuses.

  Determines overall status from a collection of individual statuses
  and provides severity ranking for sorting.
  """

  @doc """
  Determines aggregate status from a list of step statuses.

  Rules:
  - Empty list -> :running (no results yet)
  - Any :failed -> :failed
  - Some :pending, none :failed -> :pending
  - All :passed -> :passed
  """
  @spec aggregate_status([atom()]) :: atom()
  def aggregate_status([]), do: :running

  def aggregate_status(statuses) do
    cond do
      :failed in statuses -> :failed
      :pending in statuses -> :pending
      :skipped in statuses and not Enum.any?(statuses, &(&1 == :passed)) -> :skipped
      Enum.all?(statuses, &(&1 == :passed)) -> :passed
      true -> :pending
    end
  end

  @doc """
  Returns a numeric severity rank for sorting statuses.

  Higher rank = more severe.
  :failed (4) > :pending (3) > :skipped (2) > :passed (1) > other (0)
  """
  @spec severity_rank(atom()) :: non_neg_integer()
  def severity_rank(:failed), do: 4
  def severity_rank(:pending), do: 3
  def severity_rank(:skipped), do: 2
  def severity_rank(:passed), do: 1
  def severity_rank(_), do: 0
end
