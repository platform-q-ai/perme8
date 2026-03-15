defmodule Agents.Sessions.Infrastructure.TaskRunner.TodoTracker do
  @moduledoc """
  Todo list parsing, merging, and serialization extracted from TaskRunner.

  All functions are pure — they take todo data as arguments and return
  transformed results. The GenServer handles persistence and broadcasting.
  """

  alias Agents.Sessions.Domain.Entities.TodoList

  @doc """
  Parses a todo.updated SSE event payload into a list of todo item maps.

  Returns `{:ok, items}` on success or `{:error, reason}` on failure.
  """
  def parse_event(properties) when is_map(properties) do
    case TodoList.from_sse_event(%{"properties" => properties}) do
      {:ok, %TodoList{} = todo_list} -> {:ok, TodoList.to_maps(todo_list)}
      {:error, reason} -> {:error, reason}
    end
  end

  def parse_event(_), do: {:error, :invalid_payload}

  @doc """
  Merges prior resume items with current todo items.

  Prior items that share IDs with current items are dropped (current wins).
  Remaining prior items are prepended and current item positions are shifted
  by the number of kept prior items.
  """
  def merge_prior_items([], current_items), do: current_items

  def merge_prior_items(prior_items, current_items) do
    current_ids = MapSet.new(current_items, & &1["id"])
    kept_prior = Enum.reject(prior_items, &(&1["id"] in current_ids))
    offset = length(kept_prior)

    shifted_current =
      Enum.map(current_items, fn item ->
        Map.update(item, "position", offset, &(&1 + offset))
      end)

    kept_prior ++ shifted_current
  end

  @doc """
  Adds todo_items to a DB attrs map if they are non-empty.

  Returns the attrs map unchanged if todo_items is an empty list.
  """
  def put_attrs(attrs, []), do: attrs

  def put_attrs(attrs, todo_items) when is_list(todo_items) do
    Map.put(attrs, :todo_items, %{"items" => todo_items})
  end

  @doc """
  Restores todo items from the DB-persisted format.

  Returns the items list from `%{"items" => [...]}` or an empty list for
  nil/invalid input.
  """
  def restore_items(%{"items" => items}) when is_list(items), do: items
  def restore_items(_), do: []
end
