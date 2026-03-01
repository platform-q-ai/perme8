defmodule Agents.Sessions.Domain.Entities.TodoItem do
  @moduledoc """
  Pure domain entity representing a single todo step.

  This module has no infrastructure dependencies and is used for parsing,
  reasoning over, and serializing todo state.
  """

  @type status :: String.t()

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          status: status(),
          position: non_neg_integer()
        }

  defstruct [:id, :title, :position, status: "pending"]

  @doc """
  Creates a new todo item from attributes.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Returns the supported todo statuses.
  """
  @spec valid_statuses() :: [status()]
  def valid_statuses do
    ["pending", "in_progress", "completed", "failed"]
  end

  @doc """
  Returns true when the item is completed.
  """
  @spec completed?(t()) :: boolean()
  def completed?(%__MODULE__{status: "completed"}), do: true
  def completed?(%__MODULE__{}), do: false

  @doc """
  Returns true when the item has reached a terminal status.
  """
  @spec terminal?(t()) :: boolean()
  def terminal?(%__MODULE__{status: status}) do
    status in ["completed", "failed"]
  end

  @doc """
  Builds a todo item from a plain map.

  Accepts string or atom keys and applies defaults for missing values.
  """
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: value_for(map, "id", :id, ""),
      title: value_for(map, "title", :title, ""),
      status: value_for(map, "status", :status, "pending"),
      position: value_for(map, "position", :position, 0)
    }
  end

  @doc """
  Converts a todo item to a JSON-serializable map.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = todo_item) do
    %{
      "id" => todo_item.id,
      "title" => todo_item.title,
      "status" => todo_item.status,
      "position" => todo_item.position
    }
  end

  @spec value_for(map(), String.t(), atom(), term()) :: term()
  defp value_for(map, string_key, atom_key, default) do
    Map.get(map, string_key, Map.get(map, atom_key, default))
  end
end
