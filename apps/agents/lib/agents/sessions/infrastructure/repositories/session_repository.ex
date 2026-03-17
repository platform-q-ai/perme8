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
    |> to_record()
  end

  @impl true
  def get_session_for_user(id, user_id) do
    SessionQueries.base()
    |> SessionQueries.by_id(id)
    |> SessionQueries.for_user(user_id)
    |> Repo.one()
    |> to_record()
  end

  @impl true
  def update_session(%SessionRecord{id: id}, attrs) do
    case Repo.get(SessionSchema, id) do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> SessionSchema.status_changeset(attrs)
        |> Repo.update()
        |> map_result()
    end
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
    |> Enum.map(&to_record/1)
  end

  @impl true
  def delete_session(%SessionRecord{id: id}) do
    case Repo.get(SessionSchema, id) do
      nil ->
        {:error, :not_found}

      schema ->
        schema
        |> Repo.delete()
        |> map_result()
    end
  end

  @impl true
  def get_session_by_container_id(container_id) do
    SessionQueries.base()
    |> SessionQueries.by_container_id(container_id)
    |> Repo.one()
    |> to_record()
  end

  # -- Private helpers --

  defp map_result({:ok, schema}), do: {:ok, to_record(schema)}
  defp map_result({:error, _} = error), do: error

  defp to_record(nil), do: nil

  defp to_record(%SessionSchema{} = schema) do
    attrs = %{
      id: schema.id,
      user_id: schema.user_id,
      title: schema.title,
      status: schema.status,
      container_id: schema.container_id,
      container_port: schema.container_port,
      container_status: schema.container_status,
      image: schema.image,
      sdk_session_id: schema.sdk_session_id,
      paused_at: schema.paused_at,
      resumed_at: schema.resumed_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }

    # Include virtual fields from query projections (e.g., with_task_count)
    attrs =
      case Map.get(schema, :task_count) do
        nil -> attrs
        count -> Map.put(attrs, :task_count, count)
      end

    SessionRecord.new(attrs)
  end
end
