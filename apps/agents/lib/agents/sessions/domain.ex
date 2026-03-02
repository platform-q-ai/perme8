defmodule Agents.Sessions.Domain do
  @moduledoc """
  Domain layer boundary for the Sessions bounded context.

  Contains pure business logic with no external dependencies:
  - Entities: Task, TodoItem, TodoList
  - Policies: TaskPolicy
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.Task,
      Entities.TodoItem,
      Entities.TodoList,
      Policies.TaskPolicy,
      Policies.QueuePolicy,
      Events.TaskCreated,
      Events.TaskCompleted,
      Events.TaskFailed,
      Events.TaskCancelled,
      Events.TaskQueued,
      Events.TaskDeprioritised,
      Events.TaskPromoted
    ]
end
