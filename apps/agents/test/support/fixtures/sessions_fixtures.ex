defmodule Agents.SessionsFixtures do
  @moduledoc """
  Test helpers for creating session task entities.
  """

  use Boundary,
    top_level?: true,
    deps: [Agents.Sessions.Infrastructure, Agents.Test.AccountsFixtures, Identity.Repo],
    exports: []

  import Agents.Test.AccountsFixtures

  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Identity.Repo

  def task_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || user_fixture().id

    {:ok, task} =
      %TaskSchema{}
      |> TaskSchema.changeset(%{
        user_id: user_id,
        instruction: attrs[:instruction] || "Write tests for the login flow",
        status: attrs[:status] || "pending"
      })
      |> Repo.insert()

    task
  end
end
