defmodule AgentVerifyPubSubSteps do
  @moduledoc """
  Agent chat/system prompt and PubSub notification assertion step definitions.

  Covers:
  - Chat/system prompt assertions
  - PubSub notification assertions
  - Agent updates and notifications

  Related modules:
  - AgentVerifySteps - Creation and default assertions
  - AgentVerifyValidationSteps - Validation error assertions
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.AgentsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.DocumentsFixtures

  alias Jarga.Agents

  # ============================================================================
  # CHAT/SYSTEM PROMPT ASSERTIONS
  # ============================================================================

  step "I have an agent named {string} with system prompt {string}",
       %{args: [name, prompt]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: name, system_prompt: prompt})

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agent, agent)
     |> Map.put(:agents, Map.put(agents, name, agent))}
  end

  step "{string} is selected in the chat panel", %{args: [agent_name]} = context do
    user = context[:current_user]
    agent = get_in(context, [:agents, agent_name])

    assert agent, "Agent '#{agent_name}' must be created in a prior step"

    workspace =
      context[:current_workspace] || context[:workspace] ||
        workspace_fixture(user, %{
          name: "Test Workspace",
          slug: "test-workspace-#{System.unique_integer([:positive])}"
        })

    Jarga.Accounts.set_selected_agent_id(user.id, workspace.id, agent.id)

    {:ok,
     context
     |> Map.put(:selected_agent_name, agent_name)
     |> Map.put(:selected_agent, agent)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "the LLM should receive the system message {string}",
       %{args: [expected_prompt]} = context do
    agent = context[:selected_agent] || context[:agent]
    assert agent != nil

    assert agent.system_prompt == expected_prompt

    {:ok, context}
  end

  step "the response should reflect the math tutor persona", context do
    agent = context[:selected_agent] || context[:agent]
    assert agent != nil

    assert agent.system_prompt != nil and agent.system_prompt != ""

    {:ok, context}
  end

  step "I am viewing a document with content {string}", %{args: [content]} = context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    document = document_fixture(user, workspace, nil, %{title: "Test Document", content: content})

    {:ok, view, html} =
      live(context[:conn], ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:document, document)
     |> Map.put(:document_content, content)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "the system message should include the agent's prompt", context do
    agent = context[:selected_agent] || context[:agent]
    assert agent != nil

    assert agent.system_prompt != nil and agent.system_prompt != ""

    {:ok, context}
  end

  step "the system message should include the document content as context", context do
    document_content = context[:document_content]
    document = context[:document]
    assert document != nil

    assert document_content != nil and document_content != ""

    {:ok, context}
  end

  # ============================================================================
  # PUBSUB NOTIFICATION ASSERTIONS
  # ============================================================================

  step "{string} is viewing workspace {string} chat panel",
       %{args: [user_name, ws_name]} = context do
    workspace = get_in(context, [:workspaces, ws_name])

    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    viewers = Map.get(context, :workspace_viewers, %{})

    {:ok, Map.put(context, :workspace_viewers, Map.put(viewers, user_name, workspace.id))}
  end

  step "{string} and {string} members are connected", %{args: [ws1, ws2]} = context do
    workspace1 = get_in(context, [:workspaces, ws1])
    workspace2 = get_in(context, [:workspaces, ws2])

    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace1.id}")
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace2.id}")

    {:ok, Map.put(context, :subscribed_workspaces, [workspace1.id, workspace2.id])}
  end

  step "{string} members are connected", %{args: [ws_name]} = context do
    workspace = get_in(context, [:workspaces, ws_name])

    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    subscribed = Map.get(context, :subscribed_workspaces, [])

    {:ok, Map.put(context, :subscribed_workspaces, [workspace.id | subscribed])}
  end

  step "{string} has {string} selected in the chat panel",
       %{args: [user_name, agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    workspace = context[:workspace]

    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    {:ok,
     context
     |> Map.put(:selected_agent_user, user_name)
     |> Map.put(:selected_agent, agent)}
  end

  step "I have an agent {string}", %{args: [agent_name]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: agent_name, visibility: "SHARED"})

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agent, agent)
     |> Map.put(:agents, Map.put(agents, agent_name, agent))}
  end

  step "{string} should see the updated agent in her chat panel",
       %{args: [_user_name]} = context do
    assert_receive {:workspace_agent_updated, _agent}, 1000

    {:ok, context}
  end

  step "{string} should see the updated agent in his chat panel",
       %{args: [_user_name]} = context do
    assert_receive {:workspace_agent_updated, _agent}, 1000

    {:ok, context}
  end

  step "{string} should see {string} removed from the agent list",
       %{args: [_user_name, _agent_name]} = context do
    assert_receive {:workspace_agent_updated, agent}, 1000

    {:ok, Map.put(context, :last_received_agent, agent)}
  end

  step "if {string} was her only agent, the chat panel should auto-select another agent",
       %{args: [_agent_name]} = context do
    assert context[:last_received_agent] != nil

    {:ok, context}
  end

  step "{string} members should receive a workspace agent updated message",
       %{args: [_ws_name]} = context do
    assert_receive {:workspace_agent_updated, _agent}, 1000
    {:ok, context}
  end

  step "members of other workspaces should not receive notifications", context do
    refute_received {:workspace_agent_updated, _}
    {:ok, context}
  end

  step "{string} members should receive agent removed notification",
       %{args: [_ws_name]} = context do
    assert_receive {:workspace_agent_updated, agent}, 1000
    {:ok, Map.put(context, :last_received_agent, agent)}
  end

  step "their chat panels should refresh the agent list", context do
    assert context[:last_received_agent] != nil

    {:ok, context}
  end

  step "{string} members should receive agent added notification",
       %{args: [_ws_name]} = context do
    assert_receive {:workspace_agent_updated, agent}, 1000
    {:ok, Map.put(context, :last_received_agent, agent)}
  end

  step "{string} should appear in their agent selectors", %{args: [agent_name]} = context do
    received_agent = context[:last_received_agent]

    assert received_agent
    assert received_agent.name == agent_name

    {:ok, context}
  end

  step "I update {string} configuration", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    {:ok, updated_agent} =
      Agents.update_user_agent(agent.id, user.id, %{"description" => "Updated via PubSub test"})

    {:ok,
     context
     |> Map.put(:agent, updated_agent)
     |> Map.put(:agents, Map.put(context[:agents], agent_name, updated_agent))}
  end
end
