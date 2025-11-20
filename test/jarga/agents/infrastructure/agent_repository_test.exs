defmodule Jarga.Agents.Infrastructure.AgentRepositoryTest do
  use Jarga.DataCase, async: true

  alias Jarga.Agents.Infrastructure.AgentRepository
  alias Jarga.Agents.Infrastructure.Agent
  alias Jarga.Agents.Infrastructure.WorkspaceAgentJoin
  alias Jarga.Repo

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  describe "get_agent_for_user/2" do
    test "returns agent owned by user" do
      user = user_fixture()

      agent =
        %Agent{}
        |> Agent.changeset(%{
          user_id: user.id,
          name: "My Agent",
          visibility: "PRIVATE"
        })
        |> Repo.insert!()

      agent_id = agent.id
      assert %Agent{id: ^agent_id} = AgentRepository.get_agent_for_user(user.id, agent.id)
    end

    test "returns nil for agent owned by other user" do
      user = user_fixture()
      other_user = user_fixture()

      agent =
        %Agent{}
        |> Agent.changeset(%{
          user_id: other_user.id,
          name: "Other User's Agent",
          visibility: "PRIVATE"
        })
        |> Repo.insert!()

      assert nil == AgentRepository.get_agent_for_user(user.id, agent.id)
    end

    test "returns nil for non-existent agent" do
      user = user_fixture()
      non_existent_id = Ecto.UUID.generate()

      assert nil == AgentRepository.get_agent_for_user(user.id, non_existent_id)
    end
  end

  describe "list_agents_for_user/1" do
    test "returns all user's agents" do
      user = user_fixture()
      other_user = user_fixture()

      agent1 =
        %Agent{}
        |> Agent.changeset(%{
          user_id: user.id,
          name: "Agent 1",
          visibility: "PRIVATE"
        })
        |> Repo.insert!()

      agent2 =
        %Agent{}
        |> Agent.changeset(%{
          user_id: user.id,
          name: "Agent 2",
          visibility: "SHARED"
        })
        |> Repo.insert!()

      _other_agent =
        %Agent{}
        |> Agent.changeset(%{
          user_id: other_user.id,
          name: "Other Agent",
          visibility: "SHARED"
        })
        |> Repo.insert!()

      agents = AgentRepository.list_agents_for_user(user.id)

      assert length(agents) == 2
      assert Enum.any?(agents, &(&1.id == agent1.id))
      assert Enum.any?(agents, &(&1.id == agent2.id))
    end

    test "returns empty list when user has no agents" do
      user = user_fixture()

      assert [] == AgentRepository.list_agents_for_user(user.id)
    end
  end

  describe "create_agent/1" do
    test "creates agent with user_id" do
      user = user_fixture()

      attrs = %{
        user_id: user.id,
        name: "Test Agent",
        description: "Test description",
        system_prompt: "You are a helpful assistant",
        model: "gpt-4",
        temperature: 0.8,
        visibility: "PRIVATE"
      }

      assert {:ok, %Agent{} = agent} = AgentRepository.create_agent(attrs)
      assert agent.user_id == user.id
      assert agent.name == "Test Agent"
      assert agent.description == "Test description"
      assert agent.system_prompt == "You are a helpful assistant"
      assert agent.model == "gpt-4"
      assert agent.temperature == 0.8
      assert agent.visibility == "PRIVATE"
    end

    test "returns error when user_id is missing" do
      attrs = %{
        name: "Test Agent"
      }

      assert {:error, %Ecto.Changeset{} = changeset} = AgentRepository.create_agent(attrs)
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error when name is missing" do
      user = user_fixture()

      attrs = %{
        user_id: user.id
      }

      assert {:error, %Ecto.Changeset{} = changeset} = AgentRepository.create_agent(attrs)
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_agent/2" do
    test "updates agent" do
      user = user_fixture()

      agent =
        %Agent{}
        |> Agent.changeset(%{
          user_id: user.id,
          name: "Original Name",
          visibility: "PRIVATE"
        })
        |> Repo.insert!()

      update_attrs = %{
        name: "Updated Name",
        visibility: "SHARED"
      }

      assert {:ok, %Agent{} = updated_agent} =
               AgentRepository.update_agent(agent, update_attrs)

      assert updated_agent.id == agent.id
      assert updated_agent.name == "Updated Name"
      assert updated_agent.visibility == "SHARED"
    end

    test "returns error with invalid data" do
      user = user_fixture()

      agent =
        %Agent{}
        |> Agent.changeset(%{
          user_id: user.id,
          name: "Test Agent",
          visibility: "PRIVATE"
        })
        |> Repo.insert!()

      update_attrs = %{
        visibility: "INVALID"
      }

      assert {:error, %Ecto.Changeset{} = changeset} =
               AgentRepository.update_agent(agent, update_attrs)

      assert %{visibility: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "delete_agent/1" do
    test "deletes agent" do
      user = user_fixture()

      agent =
        %Agent{}
        |> Agent.changeset(%{
          user_id: user.id,
          name: "Test Agent",
          visibility: "PRIVATE"
        })
        |> Repo.insert!()

      assert {:ok, %Agent{}} = AgentRepository.delete_agent(agent)
      assert nil == Repo.get(Agent, agent.id)
    end

    test "cascade deletes workspace_agents entries" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      agent =
        %Agent{}
        |> Agent.changeset(%{
          user_id: user.id,
          name: "Test Agent",
          visibility: "PRIVATE"
        })
        |> Repo.insert!()

      workspace_agent =
        %WorkspaceAgentJoin{}
        |> WorkspaceAgentJoin.changeset(%{
          workspace_id: workspace.id,
          agent_id: agent.id
        })
        |> Repo.insert!()

      assert {:ok, %Agent{}} = AgentRepository.delete_agent(agent)
      assert nil == Repo.get(Agent, agent.id)
      assert nil == Repo.get(WorkspaceAgentJoin, workspace_agent.id)
    end
  end
end
