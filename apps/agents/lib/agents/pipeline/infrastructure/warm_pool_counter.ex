defmodule Agents.Pipeline.Infrastructure.WarmPoolCounter do
  @moduledoc """
  Default warm-pool counter.

  This is a placeholder adapter until warm-pool inventory is backed by
  concrete infrastructure.
  """

  @doc "Returns the currently available warm instance count."
  @spec current_warm_count(struct()) :: non_neg_integer() | {:error, atom()}
  def current_warm_count(_policy), do: {:error, :warm_pool_inventory_unavailable}
end
