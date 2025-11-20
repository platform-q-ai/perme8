defmodule Jarga.Agents.Infrastructure.AgentTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures

  alias Jarga.Agents.Infrastructure.Agent
  alias Jarga.Repo

  describe "Agent schema" do
    test "requires user_id (not null)" do
      changeset =
        %Agent{}
        |> Agent.changeset(%{
          name: "Test Agent",
          system_prompt: "You are a helpful assistant"
        })

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "has visibility enum (PRIVATE | SHARED)" do
      user = user_fixture()

      changeset =
        %Agent{}
        |> Agent.changeset(%{
          user_id: user.id,
          name: "Test Agent",
          system_prompt: "You are a helpful assistant",
          visibility: "PRIVATE"
        })

      assert changeset.valid?

      changeset_shared =
        %Agent{}
        |> Agent.changeset(%{
          user_id: user.id,
          name: "Test Agent",
          system_prompt: "You are a helpful assistant",
          visibility: "SHARED"
        })

      assert changeset_shared.valid?
    end

    test "has default visibility PRIVATE" do
      user = user_fixture()

      {:ok, agent} =
        %Agent{}
        |> Agent.changeset(%{
          user_id: user.id,
          name: "Test Agent",
          system_prompt: "You are a helpful assistant"
        })
        |> Repo.insert()

      assert agent.visibility == "PRIVATE"
    end

    test "changeset validates visibility values" do
      user = user_fixture()

      changeset =
        %Agent{}
        |> Agent.changeset(%{
          user_id: user.id,
          name: "Test Agent",
          system_prompt: "You are a helpful assistant",
          visibility: "INVALID"
        })

      refute changeset.valid?
      assert %{visibility: ["is invalid"]} = errors_on(changeset)
    end

    test "validates temperature range (0.0 - 2.0)" do
      user = user_fixture()

      changeset =
        %Agent{}
        |> Agent.changeset(%{
          user_id: user.id,
          name: "Test Agent",
          system_prompt: "You are a helpful assistant",
          temperature: 3.0
        })

      refute changeset.valid?
      assert %{temperature: ["must be less than or equal to 2"]} = errors_on(changeset)
    end

    test "belongs_to user association" do
      user = user_fixture()

      {:ok, agent} =
        %Agent{}
        |> Agent.changeset(%{
          user_id: user.id,
          name: "Test Agent",
          system_prompt: "You are a helpful assistant"
        })
        |> Repo.insert()

      assert agent.user_id == user.id

      # Test association loading
      agent_with_user = Repo.preload(agent, :user)
      assert agent_with_user.user.id == user.id
    end

    test "foreign key constraint on user_id" do
      changeset =
        %Agent{}
        |> Agent.changeset(%{
          user_id: Ecto.UUID.generate(),
          name: "Test Agent",
          system_prompt: "You are a helpful assistant"
        })

      assert {:error, changeset} = Repo.insert(changeset)
      assert %{user_id: ["does not exist"]} = errors_on(changeset)
    end
  end
end
