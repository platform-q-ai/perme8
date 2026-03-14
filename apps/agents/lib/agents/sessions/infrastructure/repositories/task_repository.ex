defmodule Agents.Sessions.Infrastructure.Repositories.TaskRepository do
  @moduledoc """
  Repository for managing session tasks.

  Provides persistence operations for coding tasks.
  """

  @behaviour Agents.Sessions.Application.Behaviours.TaskRepositoryBehaviour

  import Ecto.Query, warn: false

  alias Agents.Repo
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Agents.Sessions.Infrastructure.Queries.TaskQueries

  @impl true
  def create_task(attrs) do
    %TaskSchema{}
    |> TaskSchema.changeset(attrs)
    |> Repo.insert()
  end

  @impl true
  def get_task(id) do
    Repo.get(TaskSchema, id)
  end

  @impl true
  def get_task_for_user(id, user_id) do
    TaskQueries.base()
    |> TaskQueries.by_id(id)
    |> TaskQueries.for_user(user_id)
    |> Repo.one()
  end

  @impl true
  def update_task_status(%TaskSchema{} = task, attrs) do
    task
    |> TaskSchema.status_changeset(attrs)
    |> Repo.update()
  end

  @default_task_limit 50

  @impl true
  def list_tasks_for_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_task_limit)

    TaskQueries.base()
    |> TaskQueries.for_user(user_id)
    |> TaskQueries.recent_first()
    |> TaskQueries.limit(limit)
    |> Repo.all()
  end

  @impl true
  def delete_task(%TaskSchema{} = task) do
    Repo.delete(task)
  end

  @impl true
  def list_tasks_for_container(container_id, user_id) do
    TaskQueries.base()
    |> TaskQueries.for_user(user_id)
    |> TaskQueries.by_container(container_id)
    |> TaskQueries.recent_first()
    |> Repo.all()
  end

  @impl true
  def delete_tasks_for_container(container_id, user_id) do
    TaskQueries.base()
    |> TaskQueries.for_user(user_id)
    |> TaskQueries.by_container(container_id)
    |> Repo.delete_all()
  end

  @impl true
  def list_sessions_for_user(user_id, _opts \\ []) do
    TaskQueries.sessions_for_user(user_id)
    |> Repo.all()
  end

  @impl true
  def count_running_tasks(user_id) do
    TaskQueries.count_running(user_id)
    |> Repo.one()
  end

  @impl true
  def count_running_heavyweight_tasks(user_id) do
    TaskQueries.count_running_heavyweight(user_id)
    |> Repo.one()
  end

  @impl true
  def list_queued_tasks(user_id) do
    TaskQueries.queued_for_user(user_id)
    |> Repo.all()
  end

  @impl true
  def list_awaiting_feedback_tasks(user_id) do
    TaskQueries.awaiting_feedback_for_user(user_id)
    |> Repo.all()
  end

  @impl true
  def list_non_terminal_tasks(user_id) do
    TaskQueries.non_terminal_for_user(user_id)
    |> Repo.all()
  end

  @impl true
  def get_next_queued_task(user_id) do
    TaskQueries.next_queued(user_id)
    |> Repo.one()
  end

  @impl true
  def get_max_queue_position(user_id) do
    TaskQueries.max_queue_position(user_id)
    |> Repo.one()
  end

  @impl true
  def get_tasks_by_ids([]), do: []

  def get_tasks_by_ids(ids) when is_list(ids) do
    TaskQueries.base()
    |> where([t], t.id in ^ids)
    |> Repo.all()
  end
end
