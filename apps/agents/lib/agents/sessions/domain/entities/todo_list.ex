defmodule Agents.Sessions.Domain.Entities.TodoList do
  @moduledoc """
  Pure domain aggregate representing a todo list for a task.

  This module parses opencode todo SSE payloads and provides progress helpers.
  It has no infrastructure dependencies.
  """

  alias Agents.Sessions.Domain.Entities.TodoItem

  @type t :: %__MODULE__{items: [TodoItem.t()]}

  defstruct items: []

  @doc """
  Creates a new todo list from attributes.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Parses an SSE todo event payload into a todo list.

  Expected shape:
  `%{"type" => "todo.updated", "properties" => %{"todos" => [...]}}`
  """
  @spec from_sse_event(map()) :: {:ok, t()} | {:error, :invalid_payload}
  def from_sse_event(payload) when is_map(payload) do
    with {:ok, todos} <- extract_todos(payload) do
      items =
        todos
        |> Enum.with_index()
        |> Enum.map(fn {todo, index} ->
          TodoItem.new(%{
            id: Map.get(todo, "id", Map.get(todo, :id, "")),
            title:
              Map.get(
                todo,
                "content",
                Map.get(todo, :content, Map.get(todo, "title", Map.get(todo, :title, "")))
              ),
            status: Map.get(todo, "status", Map.get(todo, :status, "pending")),
            position: index
          })
        end)

      {:ok, %__MODULE__{items: items}}
    else
      _ -> {:error, :invalid_payload}
    end
  end

  @doc """
  Returns completion percentage as a float.
  """
  @spec progress_percentage(t()) :: float()
  def progress_percentage(%__MODULE__{items: []}), do: 0.0

  def progress_percentage(%__MODULE__{} = todo_list) do
    completed = completed_count(todo_list)
    total = total_count(todo_list)
    completed * 100.0 / total
  end

  @doc """
  Returns count of completed todo items.
  """
  @spec completed_count(t()) :: non_neg_integer()
  def completed_count(%__MODULE__{items: items}) do
    Enum.count(items, &TodoItem.completed?/1)
  end

  @doc """
  Returns total number of todo items.
  """
  @spec total_count(t()) :: non_neg_integer()
  def total_count(%__MODULE__{items: items}), do: length(items)

  @doc """
  Returns a user-facing progress summary.
  """
  @spec progress_summary(t()) :: String.t()
  def progress_summary(%__MODULE__{} = todo_list) do
    "#{completed_count(todo_list)}/#{total_count(todo_list)} steps complete"
  end

  @doc """
  Returns the current item being worked on.

  Prefers the first `in_progress` item. If none exist, returns the first
  `pending` item. Returns nil when no matching item exists.
  """
  @spec current_step(t()) :: TodoItem.t() | nil
  def current_step(%__MODULE__{items: items}) do
    Enum.find(items, &(&1.status == "in_progress")) || Enum.find(items, &(&1.status == "pending"))
  end

  @doc """
  Returns true when all items are completed.
  """
  @spec all_completed?(t()) :: boolean()
  def all_completed?(%__MODULE__{items: []}), do: false

  def all_completed?(%__MODULE__{items: items}) do
    Enum.all?(items, &TodoItem.completed?/1)
  end

  @doc """
  Serializes the list to plain maps.
  """
  @spec to_maps(t()) :: [map()]
  def to_maps(%__MODULE__{items: items}) do
    Enum.map(items, &TodoItem.to_map/1)
  end

  @doc """
  Deserializes a list of plain maps into a todo list.
  """
  @spec from_maps([map()]) :: t()
  def from_maps(maps) when is_list(maps) do
    %__MODULE__{items: Enum.map(maps, &TodoItem.from_map/1)}
  end

  @spec extract_todos(map()) :: {:ok, [map()]} | :error
  defp extract_todos(%{"properties" => %{"todos" => todos}}) when is_list(todos), do: {:ok, todos}
  defp extract_todos(%{properties: %{todos: todos}}) when is_list(todos), do: {:ok, todos}
  defp extract_todos(_payload), do: :error
end
