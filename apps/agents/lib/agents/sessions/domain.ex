defmodule Agents.Sessions.Domain do
  @moduledoc """
  Domain layer boundary for the Sessions bounded context.

  Contains pure business logic with no external dependencies:
  - Entities: Task
  - Events: TaskCreated, TaskStatusChanged
  - Policies: TaskPolicy
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.Task,
      Events.TaskCreated,
      Events.TaskStatusChanged,
      Policies.TaskPolicy
    ]
end
