defmodule Agents.Sessions.Infrastructure.Repositories.SessionRepository do
  @moduledoc """
  Repository for managing session aggregate roots.

  Provides persistence operations for sessions, replacing the previous
  GROUP BY container_id pattern with direct session table queries.

  All public callbacks return `SessionRecord` domain entities, keeping
  the Application layer free of Infrastructure schema dependencies.
  """

  @behaviour Agents.Sessions.Application.Behaviours.SessionRepositoryBehaviour

  alias Agents.Repo
  alias Agents.Sessions.Domain.Entities.SessionRecord
  alias Agents.Sessions.Infrastructure.Schemas.SessionSchema
  alias Agents.Sessions.Infrastructure.Queries.SessionQueries

  @impl true
  def create_session(attrs) do
    %SessionSchema{}
    |> SessionSchema.changeset(attrs)
    |> Repo.insert()
    |> map_result()
  end

  @impl true
  def get_session(id) do
    SessionSchema
    |> Repo.get(id)
    |> SessionRecord.from_schema()
  end

  @impl true
  def get_session_for_user(id, user_id) do
    SessionQueries.base()
    |> SessionQueries.by_id(id)
    |> SessionQueries.for_user(user_id)
    |> Repo.one()
    |> SessionRecord.from_schema()
  end

  @impl true
  def update_session(%SessionRecord{id: id}, attrs) do
    %SessionSchema{id: id}
    |> SessionSchema.status_changeset(attrs)
    |> Repo.update()
    |> map_result()
  rescue
    Ecto.StaleEntryError -> {:error, :not_found}
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
    |> Enum.map(&SessionRecord.from_schema/1)
  end

  @impl true
  def delete_session(%SessionRecord{id: id}) do
    %SessionSchema{id: id}
    |> Repo.delete()
    |> map_result()
  rescue
    Ecto.StaleEntryError -> {:error, :not_found}
  end

  @impl true
  def get_session_by_container_id(container_id) do
    SessionQueries.base()
    |> SessionQueries.by_container_id(container_id)
    |> Repo.one()
    |> SessionRecord.from_schema()
  end

  # -- Private helpers --

  defp map_result({:ok, schema}), do: {:ok, SessionRecord.from_schema(schema)}
  defp map_result({:error, _} = error), do: error
end
