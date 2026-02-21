defmodule Agents.Sessions.Application.UseCases.GetTask do
  @moduledoc """
  Use case for retrieving a task with ownership check.
  """

  alias Agents.Sessions.Domain.Entities.Task

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository

  @doc """
  Gets a task by ID with ownership validation.

  ## Returns
  - `{:ok, task}` - Domain entity
  - `{:error, :not_found}` - Task not found or not owned by user
  """
  def execute(task_id, user_id, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)

    case task_repo.get_task_for_user(task_id, user_id) do
      nil -> {:error, :not_found}
      schema -> {:ok, Task.from_schema(schema)}
    end
  end
end
