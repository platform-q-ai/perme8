defmodule Agents.Sessions.Application.UseCases.ListTasks do
  @moduledoc """
  Use case for listing a user's coding tasks.
  """

  alias Agents.Sessions.Domain.Entities.Task

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository

  @doc """
  Lists all tasks for a user, most recent first.

  Returns a list of domain entities.
  """
  def execute(user_id, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)

    user_id
    |> task_repo.list_tasks_for_user(opts)
    |> Enum.map(&Task.from_schema/1)
  end
end
