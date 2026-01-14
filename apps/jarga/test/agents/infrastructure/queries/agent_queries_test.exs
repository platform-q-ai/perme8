defmodule Jarga.Agents.Infrastructure.AgentQueriesTest do
  use Jarga.DataCase, async: true

  alias Jarga.Agents.Infrastructure.Schemas.{AgentSchema, WorkspaceAgentJoinSchema}
  alias Jarga.Agents.Infrastructure.Queries.AgentQueries
  alias Jarga.Repo

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  describe "for_user/2" do
    test "filters agents by user_id" do
      user1 = user_fixture()
      user2 = user_fixture()

      agent1 =
        %AgentSchema{}
        |> AgentSchema.changeset(%{user_id: user1.id, name: "Agent 1", visibility: "PRIVATE"})
        |> Repo.insert!()

      agent2 =
        %AgentSchema{}
        |> AgentSchema.changeset(%{user_id: user1.id, name: "Agent 2", visibility: "SHARED"})
        |> Repo.insert!()

      _agent3 =
        %AgentSchema{}
        |> AgentSchema.changeset(%{user_id: user2.id, name: "Agent 3", visibility: "PRIVATE"})
        |> Repo.insert!()

      agents =
        AgentSchema
        |> AgentQueries.for_user(user1.id)
        |> Repo.all()

      assert length(agents) == 2
      agent_ids = Enum.map(agents, & &1.id)
      assert agent1.id in agent_ids
      assert agent2.id in agent_ids
    end
  end

  describe "by_visibility/2" do
    test "filters agents by visibility" do
      user = user_fixture()

      private_agent =
        %AgentSchema{}
        |> AgentSchema.changeset(%{user_id: user.id, name: "Private", visibility: "PRIVATE"})
        |> Repo.insert!()

      shared_agent =
        %AgentSchema{}
        |> AgentSchema.changeset(%{user_id: user.id, name: "Shared", visibility: "SHARED"})
        |> Repo.insert!()

      # Filter for PRIVATE
      private_agents =
        AgentSchema
        |> AgentQueries.by_visibility("PRIVATE")
        |> Repo.all()

      assert length(private_agents) == 1
      assert hd(private_agents).id == private_agent.id

      # Filter for SHARED
      shared_agents =
        AgentSchema
        |> AgentQueries.by_visibility("SHARED")
        |> Repo.all()

      assert length(shared_agents) == 1
      assert hd(shared_agents).id == shared_agent.id
    end
  end

  describe "in_workspace/2" do
    test "joins with workspace_agents and filters by workspace_id" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)

      agent1 =
        %AgentSchema{}
        |> AgentSchema.changeset(%{user_id: user.id, name: "Agent 1", visibility: "PRIVATE"})
        |> Repo.insert!()

      agent2 =
        %AgentSchema{}
        |> AgentSchema.changeset(%{user_id: user.id, name: "Agent 2", visibility: "SHARED"})
        |> Repo.insert!()

      agent3 =
        %AgentSchema{}
        |> AgentSchema.changeset(%{user_id: user.id, name: "Agent 3", visibility: "PRIVATE"})
        |> Repo.insert!()

      # Add agent1 and agent2 to workspace1
      %WorkspaceAgentJoinSchema{}
      |> WorkspaceAgentJoinSchema.changeset(%{workspace_id: workspace1.id, agent_id: agent1.id})
      |> Repo.insert!()

      %WorkspaceAgentJoinSchema{}
      |> WorkspaceAgentJoinSchema.changeset(%{workspace_id: workspace1.id, agent_id: agent2.id})
      |> Repo.insert!()

      # Add agent3 to workspace2
      %WorkspaceAgentJoinSchema{}
      |> WorkspaceAgentJoinSchema.changeset(%{workspace_id: workspace2.id, agent_id: agent3.id})
      |> Repo.insert!()

      # Query agents in workspace1
      agents_in_workspace1 =
        AgentSchema
        |> AgentQueries.in_workspace(workspace1.id)
        |> Repo.all()

      assert length(agents_in_workspace1) == 2
      agent_ids = Enum.map(agents_in_workspace1, & &1.id)
      assert agent1.id in agent_ids
      assert agent2.id in agent_ids
    end
  end

  describe "base/0" do
    test "returns base query for agents" do
      query = AgentQueries.base()
      assert %Ecto.Query{} = query
    end
  end

  describe "with_workspaces/1" do
    test "preloads workspace associations" do
      # Note: This tests the query is built correctly
      # Actual preload would require proper schema associations
      query = AgentQueries.with_workspaces()
      assert %Ecto.Query{} = query
    end
  end

  describe "composability" do
    test "queries can be composed together" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)

      # user1's SHARED agent in workspace
      agent1 =
        %AgentSchema{}
        |> AgentSchema.changeset(%{user_id: user1.id, name: "User1 Shared", visibility: "SHARED"})
        |> Repo.insert!()

      # user1's PRIVATE agent in workspace
      agent2 =
        %AgentSchema{}
        |> AgentSchema.changeset(%{
          user_id: user1.id,
          name: "User1 Private",
          visibility: "PRIVATE"
        })
        |> Repo.insert!()

      # user2's SHARED agent in workspace
      agent3 =
        %AgentSchema{}
        |> AgentSchema.changeset(%{user_id: user2.id, name: "User2 Shared", visibility: "SHARED"})
        |> Repo.insert!()

      # Add agents to workspace
      %WorkspaceAgentJoinSchema{}
      |> WorkspaceAgentJoinSchema.changeset(%{workspace_id: workspace.id, agent_id: agent1.id})
      |> Repo.insert!()

      %WorkspaceAgentJoinSchema{}
      |> WorkspaceAgentJoinSchema.changeset(%{workspace_id: workspace.id, agent_id: agent2.id})
      |> Repo.insert!()

      %WorkspaceAgentJoinSchema{}
      |> WorkspaceAgentJoinSchema.changeset(%{workspace_id: workspace.id, agent_id: agent3.id})
      |> Repo.insert!()

      # Compose: user1's SHARED agents in workspace
      agents =
        AgentSchema
        |> AgentQueries.for_user(user1.id)
        |> AgentQueries.by_visibility("SHARED")
        |> AgentQueries.in_workspace(workspace.id)
        |> Repo.all()

      assert length(agents) == 1
      assert hd(agents).id == agent1.id
    end
  end
end
