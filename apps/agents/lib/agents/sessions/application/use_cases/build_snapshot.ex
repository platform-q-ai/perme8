defmodule Agents.Sessions.Application.UseCases.BuildSnapshot do
  @moduledoc """
  Use case that constructs a QueueSnapshot from current task state.

  Loads active tasks for a user and delegates lane assignment to QueueEngine.
  """

  alias Agents.Sessions.Application.SessionsConfig
  alias Agents.Sessions.Domain.Entities.QueueSnapshot
  alias Agents.Sessions.Domain.Policies.QueueEngine

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository

  @spec execute(String.t(), keyword()) :: {:ok, QueueSnapshot.t()}
  def execute(user_id, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)

    tasks = task_repo.list_tasks_for_user(user_id, status: :active)
    awaiting = task_repo.list_awaiting_feedback_tasks(user_id)
    all_tasks = tasks ++ awaiting

    config = %{
      user_id: user_id,
      concurrency_limit:
        Keyword.get(opts, :concurrency_limit, SessionsConfig.default_concurrency_limit())
    }

    snapshot = QueueEngine.build_snapshot(all_tasks, config)
    {:ok, snapshot}
  end
end
