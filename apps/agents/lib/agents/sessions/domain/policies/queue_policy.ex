defmodule Agents.Sessions.Domain.Policies.QueuePolicy do
  @moduledoc """
  Pure business rules for build queue ordering and promotion.

  Contains no I/O, no infrastructure dependencies.
  All functions are pure and deterministic.
  """

  @doc """
  Returns true if a new task should be queued (concurrency limit reached).
  """
  @spec should_queue?(non_neg_integer(), non_neg_integer()) :: boolean()
  def should_queue?(running_count, concurrency_limit) do
    running_count >= concurrency_limit
  end

  @doc """
  Returns true if there is capacity to promote a queued task.
  """
  @spec can_promote?(non_neg_integer(), non_neg_integer()) :: boolean()
  def can_promote?(running_count, concurrency_limit) do
    running_count < concurrency_limit
  end

  @doc """
  Sorts tasks by queue position (ascending), with nil positions last.
  """
  @spec sort_by_queue_position([map()]) :: [map()]
  def sort_by_queue_position(tasks) do
    Enum.sort_by(tasks, fn task ->
      case Map.get(task, :queue_position) do
        nil -> {1, 0}
        pos -> {0, pos}
      end
    end)
  end

  @doc """
  Returns the next queue position given the current maximum.
  """
  @spec next_queue_position(non_neg_integer() | nil) :: non_neg_integer()
  def next_queue_position(nil), do: 1
  def next_queue_position(current_max), do: current_max + 1

  @doc """
  Returns true when the concurrency limit is valid.
  """
  @spec valid_concurrency_limit?(term()) :: boolean()
  def valid_concurrency_limit?(limit) when is_integer(limit), do: limit in 1..10
  def valid_concurrency_limit?(_), do: false

  @doc """
  Returns true when the warm cache limit is valid.
  """
  @spec valid_warm_cache_limit?(term()) :: boolean()
  def valid_warm_cache_limit?(limit) when is_integer(limit), do: limit in 0..5
  def valid_warm_cache_limit?(_), do: false
end
