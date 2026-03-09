defmodule Agents.SessionsFixtures do
  @moduledoc """
  Test helpers for creating session task entities.
  """

  use Boundary,
    top_level?: true,
    deps: [Agents.Sessions.Infrastructure, Agents.Test.AccountsFixtures, Agents.Repo],
    exports: []

  import Agents.Test.AccountsFixtures

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Agents.Repo

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
