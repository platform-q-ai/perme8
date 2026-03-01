defmodule Agents.Sessions.Application.Behaviours.TodoAdapterBehaviour do
  @moduledoc """
  Behaviour for parsing, caching, and clearing task todo state.

  Implementations adapt external todo events into domain entities and manage
  temporary todo storage for task execution.
  """

  alias Agents.Sessions.Domain.Entities.TodoList

  @type task_id :: String.t()

  @doc """
  Parses an incoming event payload into a todo list.
  """
  @callback parse_event(event :: map()) :: {:ok, TodoList.t()} | {:error, term()}

  @doc """
  Gets cached todos for a task, if any.
  """
  @callback get_todos(task_id()) :: TodoList.t() | nil

  @doc """
  Stores todos for a task.
  """
  @callback store_todos(task_id(), TodoList.t()) :: :ok

  @doc """
  Clears cached todos for a task.
  """
  @callback clear_todos(task_id()) :: :ok
end
