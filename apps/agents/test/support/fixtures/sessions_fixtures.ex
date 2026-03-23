defmodule Agents.SessionsFixtures do
  @moduledoc """
  Test helpers for creating session and task entities.
  """

  use Boundary,
    top_level?: true,
    deps: [Agents.Sessions.Infrastructure, Agents.Test.AccountsFixtures, Agents.Repo],
    exports: []

  import Agents.Test.AccountsFixtures

  alias Agents.Sessions.Infrastructure.Schemas.{InteractionSchema, SessionSchema, TaskSchema}
  alias Agents.Repo

  def session_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || user_fixture().id

    changeset_attrs =
      %{
        user_id: user_id,
        title: attrs[:title] || "Test Session",
        status: attrs[:status] || "active",
        container_status: attrs[:container_status] || "pending"
      }
      |> maybe_put(:container_id, attrs[:container_id])
      |> maybe_put(:container_port, attrs[:container_port])
      |> maybe_put(:image, attrs[:image])
      |> maybe_put(:sdk_session_id, attrs[:sdk_session_id])
      |> maybe_put(:paused_at, attrs[:paused_at])
      |> maybe_put(:resumed_at, attrs[:resumed_at])
      |> maybe_put(:last_activity_at, attrs[:last_activity_at])

    {:ok, session} =
      %SessionSchema{}
      |> SessionSchema.changeset(changeset_attrs)
      |> Repo.insert()

    session
  end

  def interaction_fixture(attrs \\ %{}) do
    changeset_attrs =
      %{
        session_id: attrs[:session_id],
        type: attrs[:type] || "question",
        direction: attrs[:direction] || "outbound",
        payload: attrs[:payload] || %{},
        status: attrs[:status] || "pending"
      }
      |> maybe_put(:correlation_id, attrs[:correlation_id])
      |> maybe_put(:task_id, attrs[:task_id])

    {:ok, interaction} =
      %InteractionSchema{}
      |> InteractionSchema.changeset(changeset_attrs)
      |> Repo.insert()

    interaction
  end

  def task_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || user_fixture().id

    changeset_attrs =
      %{
        user_id: user_id,
        instruction: attrs[:instruction] || "Write tests for the login flow",
        status: attrs[:status] || "pending"
      }
      |> maybe_put(:error, attrs[:error])
      |> maybe_put(:lifecycle_state, attrs[:lifecycle_state])
      |> maybe_put(:container_id, attrs[:container_id])
      |> maybe_put(:session_id, attrs[:session_id])
      |> maybe_put(:output, attrs[:output])
      |> maybe_put(:image, attrs[:image])

    {:ok, task} =
      %TaskSchema{}
      |> TaskSchema.changeset(changeset_attrs)
      |> Repo.insert()

    task =
      if attrs[:todo_items] do
        {:ok, updated} =
          task
          |> TaskSchema.status_changeset(%{todo_items: attrs[:todo_items]})
          |> Repo.update()

        updated
      else
        task
      end

    task
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
