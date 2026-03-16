defmodule Agents.Sessions.Infrastructure.Repositories.SessionRepository do
  @moduledoc """
  Repository for managing session aggregate roots.

  Provides persistence operations for sessions, replacing the previous
  GROUP BY container_id pattern with direct session table queries.
  """

  @behaviour Agents.Sessions.Application.Behaviours.SessionRepositoryBehaviour

  alias Agents.Repo
  alias Agents.Sessions.Infrastructure.Schemas.SessionSchema
  alias Agents.Sessions.Infrastructure.Queries.SessionQueries

  @impl true
  def create_session(attrs) do
    %SessionSchema{}
    |> SessionSchema.changeset(attrs)
    |> Repo.insert()
  end

  @impl true
  def get_session(id) do
    Repo.get(SessionSchema, id)
  end

  @impl true
  def get_session_for_user(id, user_id) do
    SessionQueries.base()
    |> SessionQueries.by_id(id)
    |> SessionQueries.for_user(user_id)
    |> Repo.one()
  end

  @impl true
  def update_session(%SessionSchema{} = session, attrs) do
    session
    |> SessionSchema.status_changeset(attrs)
    |> Repo.update()
  end

  @default_session_limit 50

  @impl true
  def list_sessions_for_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_session_limit)

    SessionQueries.base()
    |> SessionQueries.for_user(user_id)
    |> SessionQueries.with_task_count()
    |> SessionQueries.recent_first()
    |> SessionQueries.limit(limit)
    |> Repo.all()
  end

  @impl true
  def delete_session(%SessionSchema{} = session) do
    Repo.delete(session)
  end

  @impl true
  def get_session_by_container_id(container_id) do
    SessionQueries.base()
    |> SessionQueries.by_container_id(container_id)
    |> Repo.one()
  end
end
