defmodule Jarga.AgentsTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Jarga.Agents
  alias Jarga.Agents.Infrastructure.{Agent, WorkspaceAgentJoin}
  alias Jarga.Repo

  describe "list_user_agents/1" do
    test "lists all agents owned by user" do
      user = user_fixture()
      other_user = user_fixture()

      # Create agents for user
      {:ok, agent1} = Agents.create_user_agent(%{user_id: user.id, name: "Agent 1"})
      {:ok, agent2} = Agents.create_user_agent(%{user_id: user.id, name: "Agent 2"})

      # Create agent for other user
      {:ok, _other_agent} = Agents.create_user_agent(%{user_id: other_user.id, name: "Other"})

      agents = Agents.list_user_agents(user.id)

      assert length(agents) == 2
      assert Enum.any?(agents, &(&1.id == agent1.id))
      assert Enum.any?(agents, &(&1.id == agent2.id))
    end

    test "returns empty list when user has no agents" do
      user = user_fixture()
      assert [] = Agents.list_user_agents(user.id)
    end
  end

  describe "create_user_agent/1" do
    test "creates agent with user_id" do
      user = user_fixture()

      attrs = %{
        user_id: user.id,
        name: "Test Agent",
        description: "Test description",
        system_prompt: "You are helpful",
        model: "gpt-4",
        temperature: 0.8,
        visibility: "PRIVATE"
      }

      assert {:ok, %Agent{} = agent} = Agents.create_user_agent(attrs)
      assert agent.user_id == user.id
      assert agent.name == "Test Agent"
      assert agent.visibility == "PRIVATE"
    end

    test "defaults visibility to PRIVATE" do
      user = user_fixture()

      attrs = %{user_id: user.id, name: "Agent"}

      assert {:ok, agent} = Agents.create_user_agent(attrs)
      assert agent.visibility == "PRIVATE"
    end
  end

  describe "update_user_agent/3" do
    test "updates agent when user is owner" do
      user = user_fixture()
      {:ok, agent} = Agents.create_user_agent(%{user_id: user.id, name: "Original"})

      assert {:ok, updated} = Agents.update_user_agent(agent.id, user.id, %{name: "Updated"})
      assert updated.name == "Updated"
    end

    test "returns error when user is not owner" do
      user = user_fixture()
      other_user = user_fixture()
      {:ok, agent} = Agents.create_user_agent(%{user_id: user.id, name: "Agent"})

      assert {:error, :not_found} =
               Agents.update_user_agent(agent.id, other_user.id, %{name: "Hacked"})
    end
  end

  describe "delete_user_agent/2" do
    test "deletes agent when user is owner" do
      user = user_fixture()
      {:ok, agent} = Agents.create_user_agent(%{user_id: user.id, name: "Agent"})

      assert {:ok, deleted} = Agents.delete_user_agent(agent.id, user.id)
      assert deleted.id == agent.id
      assert nil == Repo.get(Agent, agent.id)
    end

    test "returns error when user is not owner" do
      user = user_fixture()
      other_user = user_fixture()
      {:ok, agent} = Agents.create_user_agent(%{user_id: user.id, name: "Agent"})

      assert {:error, :not_found} = Agents.delete_user_agent(agent.id, other_user.id)
      assert Repo.get(Agent, agent.id) != nil
    end
  end

  describe "clone_shared_agent/2" do
    test "clones shared agent to user's library with workspace context" do
      owner = user_fixture()
      cloner = user_fixture()
      workspace = workspace_fixture(owner)

      add_workspace_member_fixture(workspace.id, cloner, :member)

      {:ok, original} =
        Agents.create_user_agent(%{
          user_id: owner.id,
          name: "Original Agent",
          system_prompt: "Test prompt",
          model: "gpt-4",
          temperature: 0.7,
          visibility: "SHARED"
        })

      Agents.sync_agent_workspaces(original.id, owner.id, [workspace.id])

      assert {:ok, cloned} =
               Agents.clone_shared_agent(original.id, cloner.id, workspace_id: workspace.id)

      assert cloned.user_id == cloner.id
      assert cloned.name == "Original Agent (Copy)"
      assert cloned.system_prompt == "Test prompt"
      assert cloned.model == "gpt-4"
      assert cloned.temperature == 0.7
      assert cloned.visibility == "PRIVATE"
      assert cloned.id != original.id
    end

    test "returns error when cloning private agent as non-owner" do
      owner = user_fixture()
      cloner = user_fixture()

      {:ok, original} =
        Agents.create_user_agent(%{
          user_id: owner.id,
          name: "Private Agent",
          visibility: "PRIVATE"
        })

      assert {:error, :forbidden} = Agents.clone_shared_agent(original.id, cloner.id)
    end

    test "owner can clone their own private agent" do
      user = user_fixture()

      {:ok, original} =
        Agents.create_user_agent(%{
          user_id: user.id,
          name: "My Agent",
          visibility: "PRIVATE"
        })

      assert {:ok, cloned} = Agents.clone_shared_agent(original.id, user.id)
      assert cloned.name == "My Agent (Copy)"
      assert cloned.visibility == "PRIVATE"
    end

    test "non-owner can clone shared agent with workspace context" do
      owner = user_fixture()
      cloner = user_fixture()
      workspace = workspace_fixture(owner)

      add_workspace_member_fixture(workspace.id, cloner, :member)

      {:ok, original} =
        Agents.create_user_agent(%{
          user_id: owner.id,
          name: "Shared Agent",
          visibility: "SHARED"
        })

      Agents.sync_agent_workspaces(original.id, owner.id, [workspace.id])

      assert {:ok, cloned} =
               Agents.clone_shared_agent(original.id, cloner.id, workspace_id: workspace.id)

      assert cloned.user_id == cloner.id
      assert cloned.name == "Shared Agent (Copy)"
    end

    test "non-owner cannot clone shared agent without workspace context" do
      owner = user_fixture()
      cloner = user_fixture()

      {:ok, original} =
        Agents.create_user_agent(%{
          user_id: owner.id,
          name: "Shared Agent",
          visibility: "SHARED"
        })

      assert {:error, :forbidden} = Agents.clone_shared_agent(original.id, cloner.id)
    end

    test "returns not_found error when agent does not exist" do
      user = user_fixture()
      non_existent_id = Ecto.UUID.generate()

      assert {:error, :not_found} = Agents.clone_shared_agent(non_existent_id, user.id)
    end
  end

  describe "list_workspace_available_agents/2" do
    test "returns my_agents in workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      # Create user's agent and add to workspace
      {:ok, my_agent} =
        Agents.create_user_agent(%{user_id: user.id, name: "My Agent", visibility: "SHARED"})

      add_agent_to_workspace(my_agent.id, workspace.id)

      result = Agents.list_workspace_available_agents(workspace.id, user.id)

      assert length(result.my_agents) == 1
      assert hd(result.my_agents).id == my_agent.id
    end

    test "returns empty lists when no agents in workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      result = Agents.list_workspace_available_agents(workspace.id, user.id)

      assert result.my_agents == []
      assert result.other_agents == []
    end

    test "includes both private and shared user agents in my_agents" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, private_agent} =
        Agents.create_user_agent(%{user_id: user.id, name: "Private", visibility: "PRIVATE"})

      {:ok, shared_agent} =
        Agents.create_user_agent(%{user_id: user.id, name: "Shared", visibility: "SHARED"})

      add_agent_to_workspace(private_agent.id, workspace.id)
      add_agent_to_workspace(shared_agent.id, workspace.id)

      result = Agents.list_workspace_available_agents(workspace.id, user.id)

      assert length(result.my_agents) == 2
    end
  end

  describe "cancel_agent_query/2" do
    test "sends cancel message to query process" do
      # Create a process to receive the message
      parent = self()

      query_pid =
        spawn(fn ->
          receive do
            {:cancel, node_id} -> send(parent, {:received_cancel, node_id})
          after
            1000 -> send(parent, :timeout)
          end
        end)

      assert :ok = Agents.cancel_agent_query(query_pid, "node_123")

      assert_receive {:received_cancel, "node_123"}, 500
    end
  end

  describe "chat context preparation" do
    test "prepare_chat_context/1 extracts context from assigns" do
      workspace = workspace_fixture(user_fixture())

      assigns = %{
        current_workspace: workspace
      }

      {:ok, context} = Agents.prepare_chat_context(assigns)

      assert context.current_workspace == workspace.name
    end

    test "build_system_message/1 creates system message from context" do
      context = %{
        current_workspace: "ACME Corp"
      }

      {:ok, message} = Agents.build_system_message(context)

      assert message.role == "system"
      assert message.content =~ "ACME Corp"
    end
  end

  describe "session management" do
    test "create_session/1 creates a new chat session" do
      user = user_fixture()

      attrs = %{user_id: user.id, title: "Test Session"}

      assert {:ok, session} = Agents.create_session(attrs)
      assert session.user_id == user.id
      assert session.title == "Test Session"
    end

    test "load_session/1 loads session with messages" do
      user = user_fixture()
      {:ok, session} = Agents.create_session(%{user_id: user.id})

      {:ok, _msg} =
        Agents.save_message(%{
          chat_session_id: session.id,
          role: "user",
          content: "Hello"
        })

      assert {:ok, loaded} = Agents.load_session(session.id)
      assert loaded.id == session.id
      assert length(loaded.messages) == 1
    end

    test "list_sessions/1 lists user's sessions" do
      user = user_fixture()
      {:ok, session1} = Agents.create_session(%{user_id: user.id})
      {:ok, session2} = Agents.create_session(%{user_id: user.id})

      {:ok, sessions} = Agents.list_sessions(user.id)

      assert length(sessions) == 2
      session_ids = Enum.map(sessions, & &1.id)
      assert session1.id in session_ids
      assert session2.id in session_ids
    end

    test "delete_session/2 removes session" do
      user = user_fixture()
      {:ok, session} = Agents.create_session(%{user_id: user.id})

      assert {:ok, _deleted} = Agents.delete_session(session.id, user.id)
      assert {:error, :not_found} = Agents.load_session(session.id)
    end

    test "save_message/1 adds message to session" do
      user = user_fixture()
      {:ok, session} = Agents.create_session(%{user_id: user.id})

      attrs = %{
        chat_session_id: session.id,
        role: "user",
        content: "Test message"
      }

      assert {:ok, message} = Agents.save_message(attrs)
      assert message.content == "Test message"
      assert message.role == "user"
    end
  end

  describe "get_workspace_agents_list/3 (flat list for UI components)" do
    test "returns flat list of agents for workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, agent1} =
        Agents.create_user_agent(%{user_id: user.id, name: "Agent 1", visibility: "SHARED"})

      {:ok, agent2} =
        Agents.create_user_agent(%{user_id: user.id, name: "Agent 2", visibility: "PRIVATE"})

      add_agent_to_workspace(agent1.id, workspace.id)
      add_agent_to_workspace(agent2.id, workspace.id)

      agents = Agents.get_workspace_agents_list(workspace.id, user.id)

      assert length(agents) == 2
    end

    test "filters by enabled_only option" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, enabled_agent} =
        Agents.create_user_agent(%{
          user_id: user.id,
          name: "Enabled",
          enabled: true,
          visibility: "SHARED"
        })

      {:ok, disabled_agent} =
        Agents.create_user_agent(%{
          user_id: user.id,
          name: "Disabled",
          enabled: false,
          visibility: "SHARED"
        })

      add_agent_to_workspace(enabled_agent.id, workspace.id)
      add_agent_to_workspace(disabled_agent.id, workspace.id)

      agents = Agents.get_workspace_agents_list(workspace.id, user.id, enabled_only: true)

      assert length(agents) == 1
      assert hd(agents).id == enabled_agent.id
    end

    test "returns empty list when workspace has no agents" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      agents = Agents.get_workspace_agents_list(workspace.id, user.id)

      assert agents == []
    end

    test "returns all agents when enabled_only is false" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, enabled} = Agents.create_user_agent(%{user_id: user.id, name: "E", enabled: true})
      {:ok, disabled} = Agents.create_user_agent(%{user_id: user.id, name: "D", enabled: false})

      add_agent_to_workspace(enabled.id, workspace.id)
      add_agent_to_workspace(disabled.id, workspace.id)

      agents = Agents.get_workspace_agents_list(workspace.id, user.id, enabled_only: false)

      assert length(agents) == 2
    end
  end

  # Helper functions
  defp add_agent_to_workspace(agent_id, workspace_id) do
    %WorkspaceAgentJoin{}
    |> WorkspaceAgentJoin.changeset(%{
      agent_id: agent_id,
      workspace_id: workspace_id
    })
    |> Repo.insert!()
  end
end
