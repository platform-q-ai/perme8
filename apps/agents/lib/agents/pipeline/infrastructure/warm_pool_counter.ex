defmodule Agents.Pipeline.Infrastructure.WarmPoolCounter do
  @moduledoc """
  Default warm-pool counter.

  This is a placeholder adapter until warm-pool inventory is backed by
  concrete infrastructure. It returns zero so replenishment executes whenever
  the configured target count is positive.
  """

  @doc "Returns the currently available warm instance count."
  @spec current_warm_count(struct()) :: non_neg_integer()
  def current_warm_count(_policy), do: 0
end
