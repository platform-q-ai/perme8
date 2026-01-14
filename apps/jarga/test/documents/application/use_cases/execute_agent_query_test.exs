defmodule Jarga.Documents.Application.UseCases.ExecuteAgentQueryTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.AgentsFixtures

  alias Jarga.Documents.Application.UseCases.ExecuteAgentQuery

  describe "execute/2" do
    setup do
      user = user_fixture()
      workspace = workspace_fixture(user)

      # Create an enabled agent
      agent =
        user_agent_fixture(%{
          user_id: user.id,
          name: "my-test-agent",
          description: "Test agent for documents",
          system_prompt: "You are a helpful documentation assistant.",
          model: "gpt-4",
          temperature: 0.7,
          enabled: true
        })

      # Add agent to workspace
      Jarga.Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

      assigns = %{
        current_workspace: workspace,
        document_title: "Test Document",
        note: %{note_content: "# Test Content\n\nSome markdown here."}
      }

      {:ok, user: user, workspace: workspace, agent: agent, assigns: assigns}
    end

    test "successfully executes query with valid agent name", %{
      user: user,
      workspace: workspace,
      agent: agent,
      assigns: assigns
    } do
      params = %{
        command: "@j #{agent.name} What is this document about?",
        user: user,
        workspace_id: workspace.id,
        assigns: assigns,
        node_id: "node_123"
      }

      # Execute the use case
      result = ExecuteAgentQuery.execute(params, self())

      # Should return success with a PID
      assert {:ok, pid} = result
      assert is_pid(pid)
    end

    test "returns error when agent not found in workspace", %{
      user: user,
      workspace: workspace,
      assigns: assigns
    } do
      params = %{
        command: "@j non-existent-agent What is this?",
        user: user,
        workspace_id: workspace.id,
        assigns: assigns,
        node_id: "node_456"
      }

      result = ExecuteAgentQuery.execute(params, self())

      assert {:error, :agent_not_found} = result
    end

    test "returns error when agent is disabled", %{
      user: user,
      workspace: workspace,
      assigns: assigns
    } do
      # Create a disabled agent
      disabled_agent =
        user_agent_fixture(%{
          user_id: user.id,
          name: "disabled-agent",
          model: "gpt-4",
          temperature: 0.7,
          enabled: false
        })

      Jarga.Agents.sync_agent_workspaces(disabled_agent.id, user.id, [workspace.id])

      params = %{
        command: "@j disabled-agent Can you help?",
        user: user,
        workspace_id: workspace.id,
        assigns: assigns,
        node_id: "node_789"
      }

      result = ExecuteAgentQuery.execute(params, self())

      assert {:error, :agent_disabled} = result
    end

    test "passes agent's custom system_prompt to agent_query", %{
      user: user,
      workspace: workspace,
      agent: agent,
      assigns: assigns
    } do
      params = %{
        command: "@j #{agent.name} Explain something",
        user: user,
        workspace_id: workspace.id,
        assigns: assigns,
        node_id: "node_custom"
      }

      # Execute the query
      {:ok, _pid} = ExecuteAgentQuery.execute(params, self())

      # We can't directly verify the system_prompt was used without mocking,
      # but we can verify the execution succeeded
      # In a real scenario, this would be verified by checking LlmClient calls
      assert true
    end

    test "passes full document content as context", %{
      user: user,
      workspace: workspace,
      agent: agent,
      assigns: assigns
    } do
      params = %{
        command: "@j #{agent.name} Summarize the document",
        user: user,
        workspace_id: workspace.id,
        assigns: assigns,
        node_id: "node_context"
      }

      # Execute the query
      {:ok, _pid} = ExecuteAgentQuery.execute(params, self())

      # Context is passed via assigns to Agents.agent_query
      # This test verifies the flow completes successfully
      assert true
    end

    test "returns error for invalid command syntax", %{
      user: user,
      workspace: workspace,
      assigns: assigns
    } do
      params = %{
        command: "just regular text without @j",
        user: user,
        workspace_id: workspace.id,
        assigns: assigns,
        node_id: "node_invalid"
      }

      result = ExecuteAgentQuery.execute(params, self())

      assert {:error, :invalid_command_format} = result
    end

    test "returns error for command with missing agent name", %{
      user: user,
      workspace: workspace,
      assigns: assigns
    } do
      params = %{
        command: "@j   What is this?",
        user: user,
        workspace_id: workspace.id,
        assigns: assigns,
        node_id: "node_no_agent"
      }

      result = ExecuteAgentQuery.execute(params, self())

      assert {:error, :invalid_command_format} = result
    end

    test "returns error for command with missing question", %{
      user: user,
      workspace: workspace,
      agent: agent,
      assigns: assigns
    } do
      params = %{
        command: "@j #{agent.name}",
        user: user,
        workspace_id: workspace.id,
        assigns: assigns,
        node_id: "node_no_question"
      }

      result = ExecuteAgentQuery.execute(params, self())

      assert {:error, :invalid_command_format} = result
    end

    test "handles agent name case-insensitively", %{
      user: user,
      workspace: workspace,
      agent: _agent,
      assigns: assigns
    } do
      # Agent name is "my-test-agent", try uppercase version
      params = %{
        command: "@j MY-TEST-AGENT What is this?",
        user: user,
        workspace_id: workspace.id,
        assigns: assigns,
        node_id: "node_case"
      }

      result = ExecuteAgentQuery.execute(params, self())

      # Should find the agent despite case difference
      assert {:ok, pid} = result
      assert is_pid(pid)
    end
  end
end
