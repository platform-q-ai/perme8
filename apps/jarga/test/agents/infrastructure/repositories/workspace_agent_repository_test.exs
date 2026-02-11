defmodule Jarga.Agents.Infrastructure.WorkspaceAgentRepositoryTest do
  use Jarga.DataCase, async: true

  alias Jarga.Agents.Infrastructure.Repositories.WorkspaceAgentRepository
  alias Jarga.Agents.Infrastructure.Schemas.AgentSchema
  alias Jarga.Agents.Infrastructure.Schemas.WorkspaceAgentJoinSchema
  # Use Identity.Repo for all operations to ensure consistent transaction visibility
  alias Identity.Repo, as: Repo

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  describe "add_to_workspace/2" do
    test "creates workspace_agents entry" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      agent =
        %AgentSchema{}
        |> AgentSchema.changeset(%{
          user_id: user.id,
          name: "Test Agent",
          visibility: "PRIVATE"
        })
        |> Repo.insert!()

      assert {:ok, %WorkspaceAgentJoinSchema{} = workspace_agent} =
               WorkspaceAgentRepository.add_to_workspace(workspace.id, agent.id)

      assert workspace_agent.workspace_id == workspace.id
      assert workspace_agent.agent_id == agent.id
    end

    test "returns error on duplicate workspace-agent association" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      agent =
        %AgentSchema{}
        |> AgentSchema.changeset(%{
          user_id: user.id,
          name: "Test Agent",
          visibility: "PRIVATE"
        })
        |> Repo.insert!()

      # First addition should succeed
      assert {:ok, _} = WorkspaceAgentRepository.add_to_workspace(workspace.id, agent.id)

      # Second addition should fail with unique constraint
      assert {:error, %Ecto.Changeset{} = changeset} =
               WorkspaceAgentRepository.add_to_workspace(workspace.id, agent.id)

      assert %{workspace_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "remove_from_workspace/2" do
    test "deletes workspace_agents entry" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      agent =
        %AgentSchema{}
        |> AgentSchema.changeset(%{
          user_id: user.id,
          name: "Test Agent",
          visibility: "PRIVATE"
        })
        |> Repo.insert!()

      workspace_agent =
        %WorkspaceAgentJoinSchema{}
        |> WorkspaceAgentJoinSchema.changeset(%{
          workspace_id: workspace.id,
          agent_id: agent.id
        })
        |> Repo.insert!()

      assert :ok = WorkspaceAgentRepository.remove_from_workspace(workspace.id, agent.id)
      assert nil == Repo.get(WorkspaceAgentJoinSchema, workspace_agent.id)
    end

    test "returns ok if entry doesn't exist" do
      workspace_id = Ecto.UUID.generate()
      agent_id = Ecto.UUID.generate()

      assert :ok = WorkspaceAgentRepository.remove_from_workspace(workspace_id, agent_id)
    end
  end

  describe "list_workspace_agents/2" do
    test "returns agents for workspace with user's agents" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(user)

      # Add other_user to workspace
      add_workspace_member_fixture(workspace.id, other_user, :member)

      # User's private agent in workspace
      my_private_agent =
        %AgentSchema{}
        |> AgentSchema.changeset(%{
          user_id: user.id,
          name: "My Private Agent",
          visibility: "PRIVATE"
        })
        |> Repo.insert!()

      # User's shared agent in workspace
      my_shared_agent =
        %AgentSchema{}
        |> AgentSchema.changeset(%{
          user_id: user.id,
          name: "My Shared Agent",
          visibility: "SHARED"
        })
        |> Repo.insert!()

      # Other user's shared agent in workspace
      other_shared_agent =
        %AgentSchema{}
        |> AgentSchema.changeset(%{
          user_id: other_user.id,
          name: "Other Shared Agent",
          visibility: "SHARED"
        })
        |> Repo.insert!()

      # Other user's private agent in workspace (should be hidden)
      other_private_agent =
        %AgentSchema{}
        |> AgentSchema.changeset(%{
          user_id: other_user.id,
          name: "Other Private Agent",
          visibility: "PRIVATE"
        })
        |> Repo.insert!()

      # Add agents to workspace
      %WorkspaceAgentJoinSchema{}
      |> WorkspaceAgentJoinSchema.changeset(%{
        workspace_id: workspace.id,
        agent_id: my_private_agent.id
      })
      |> Repo.insert!()

      %WorkspaceAgentJoinSchema{}
      |> WorkspaceAgentJoinSchema.changeset(%{
        workspace_id: workspace.id,
        agent_id: my_shared_agent.id
      })
      |> Repo.insert!()

      %WorkspaceAgentJoinSchema{}
      |> WorkspaceAgentJoinSchema.changeset(%{
        workspace_id: workspace.id,
        agent_id: other_shared_agent.id
      })
      |> Repo.insert!()

      %WorkspaceAgentJoinSchema{}
      |> WorkspaceAgentJoinSchema.changeset(%{
        workspace_id: workspace.id,
        agent_id: other_private_agent.id
      })
      |> Repo.insert!()

      result = WorkspaceAgentRepository.list_workspace_agents(workspace.id, user.id)

      assert %{my_agents: my_agents, other_agents: other_agents} = result

      # User should see both their private and shared agents
      assert length(my_agents) == 2
      my_agent_ids = Enum.map(my_agents, & &1.id)
      assert my_private_agent.id in my_agent_ids
      assert my_shared_agent.id in my_agent_ids

      # User should only see other user's SHARED agent
      assert length(other_agents) == 1
      assert hd(other_agents).id == other_shared_agent.id
    end

    test "returns empty lists when workspace has no agents" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      result = WorkspaceAgentRepository.list_workspace_agents(workspace.id, user.id)

      assert %{my_agents: [], other_agents: []} = result
    end
  end

  describe "agent_in_workspace?/2" do
    test "returns true when agent is in workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      agent =
        %AgentSchema{}
        |> AgentSchema.changeset(%{
          user_id: user.id,
          name: "Test Agent",
          visibility: "PRIVATE"
        })
        |> Repo.insert!()

      %WorkspaceAgentJoinSchema{}
      |> WorkspaceAgentJoinSchema.changeset(%{
        workspace_id: workspace.id,
        agent_id: agent.id
      })
      |> Repo.insert!()

      assert WorkspaceAgentRepository.agent_in_workspace?(workspace.id, agent.id) == true
    end

    test "returns false when agent is not in workspace" do
      workspace_id = Ecto.UUID.generate()
      agent_id = Ecto.UUID.generate()

      assert WorkspaceAgentRepository.agent_in_workspace?(workspace_id, agent_id) == false
    end
  end
end
