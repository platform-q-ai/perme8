defmodule Agents.Sessions.Infrastructure.Repositories.TaskRepository do
  @moduledoc """
  Repository for managing session tasks.

  Provides persistence operations for coding tasks.
  """

  @behaviour Agents.Sessions.Application.Behaviours.TaskRepositoryBehaviour

  import Ecto.Query, warn: false

  alias Identity.Repo, as: Repo
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

  @impl true
  def list_tasks_for_user(user_id, _opts \\ []) do
    TaskQueries.base()
    |> TaskQueries.for_user(user_id)
    |> TaskQueries.recent_first()
    |> Repo.all()
  end

  @impl true
  def running_task_count_for_user(user_id) do
    TaskQueries.running_count_for_user(user_id)
    |> Repo.one()
  end
end
