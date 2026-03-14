defmodule Agents.Tickets.Domain.Policies.TicketDependencyPolicy do
  @moduledoc """
  Pure validation rules for ticket dependency (blocks/blocked-by) relationships.

  All functions are pure — no I/O, no Repo calls. They operate on
  in-memory edge lists passed in by the caller.
  """

  @type edge :: {integer(), integer()}

  @doc """
  Returns true if adding the proposed edge (blocker_id → blocked_id)
  would create a cycle in the directed dependency graph.

  Uses DFS from `blocked_id` following forward edges to detect if
  `blocker_id` is reachable through existing edges.
  """
  @spec circular_dependency?([edge()], integer(), integer()) :: boolean()
  def circular_dependency?(_edges, blocker_id, blocked_id) when blocker_id == blocked_id, do: true

  def circular_dependency?(edges, blocker_id, blocked_id) do
    # We need to check: after adding blocker_id → blocked_id,
    # can we follow edges from blocked_id back to blocker_id?
    # That means: is blocker_id reachable from blocked_id via existing edges?
    reachable?(edges, blocked_id, blocker_id, MapSet.new())
  end

  @doc """
  Returns true if the edge already exists in the edge list.
  """
  @spec duplicate_dependency?([edge()], {integer(), integer()}) :: boolean()
  def duplicate_dependency?(edges, {blocker_id, blocked_id}) do
    Enum.member?(edges, {blocker_id, blocked_id})
  end

  @doc """
  Returns true if the blocker and blocked IDs are different (valid).
  Returns false for self-references.
  """
  @spec valid_dependency?(integer(), integer()) :: boolean()
  def valid_dependency?(blocker_id, blocked_id), do: blocker_id != blocked_id

  # DFS: from `current`, follow outgoing edges, check if `target` is reachable
  defp reachable?(_edges, current, target, _visited) when current == target, do: true

  defp reachable?(edges, current, target, visited) do
    if MapSet.member?(visited, current) do
      false
    else
      visited = MapSet.put(visited, current)

      edges
      |> Enum.filter(fn {blocker, _blocked} -> blocker == current end)
      |> Enum.any?(fn {_blocker, blocked} -> reachable?(edges, blocked, target, visited) end)
    end
  end
end
