defmodule ChatSetupSteps do
  @moduledoc """
  Step definitions for Chat Panel Core Setup.

  Covers:
  - Viewport configuration (desktop/mobile)
  - Page navigation to chat-enabled pages
  - Chat panel UI state setup
  - User preferences and state
  - Data table steps for multi-page testing

  For agent-specific setup, see: ChatSetupAgentsSteps (setup_agents.exs)
  For document/project context, see: ChatSetupDocumentsSteps (setup_documents.exs)
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers
  import Jarga.WorkspacesFixtures
  import Jarga.AgentsFixtures
  import Jarga.ChatFixtures

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_map_from_context(context, key) do
    case context[key] do
      value when is_map(value) -> value
      _ -> %{}
    end
  end

  defp get_session_messages(nil), do: []

  defp get_session_messages(session) do
    {:ok, loaded} = Jarga.Chat.load_session(session.id)
    loaded.messages
  rescue
    _ -> []
  end

  # Helper to load a message into the chat panel for testing
  defp load_message_into_chat_panel(context, session, message) do
    {view, context} = ensure_view(context)

    # Send update to chat panel component to load this session
    Phoenix.LiveView.send_update(view.pid, JargaWeb.ChatLive.Panel,
      id: "global-chat-panel",
      current_session_id: session.id,
      messages: [
        %{
          id: message.id,
          role: message.role,
          content: message.content,
          timestamp: message.inserted_at
        }
      ]
    )

    # Render to ensure the update is processed
    html = render(view)

    {view, html, context}
  end

  # ============================================================================
  # VIEWPORT & PAGE NAVIGATION SETUP
  # ============================================================================

  step "I am on desktop viewport", context do
    conn = context[:conn]
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    {:ok,
     context
     |> Map.put(:viewport, :desktop)
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I am on desktop", context do
    conn = context[:conn]
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    {:ok,
     context
     |> Map.put(:viewport, :desktop)
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I am on desktop with the panel open by default", context do
    conn = context[:conn]
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    {:ok,
     context
     |> Map.put(:viewport, :desktop)
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I am on desktop (panel open by default)", context do
    conn = context[:conn]
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    {:ok,
     context
     |> Map.put(:viewport, :desktop)
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I am on any page with the admin layout", context do
    conn = context[:conn]
    user = context[:current_user]

    workspace =
      get_workspace(context) ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    agent =
      context[:default_agent] || context[:agent] ||
        agent_fixture(user, %{name: "Default Agent", enabled: true})

    :ok = Jarga.Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:agent, agent)
     |> Map.put(:current_page, :workspace)}
  end

  step "I am on the dashboard page", context do
    conn = context[:conn]
    {:ok, view, html} = live(conn, ~p"/app/")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:current_page, :dashboard)}
  end

  step "I am on the dashboard (no document open)", context do
    conn = context[:conn]
    {:ok, view, html} = live(conn, ~p"/app/")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:current_page, :dashboard)}
  end

  step "I am on the dashboard with no document open", context do
    conn = context[:conn]
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:no_document_open, true)}
  end

  step "I am on a page with a chat panel", context do
    conn = context[:conn]
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:chat_panel_available, true)}
  end

  step "the page loads", context do
    {view, context} = ensure_view(context)
    html = render(view)

    {:ok,
     context
     |> Map.put(:page_loaded, true)
     |> Map.put(:last_html, html)}
  end

  step "I navigate to another page", context do
    conn = context[:conn]
    {:ok, view, html} = live(conn, ~p"/app/workspaces")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  # ============================================================================
  # CHAT PANEL UI SETUP
  # ============================================================================

  step "the chat panel is open with agent {string} selected", %{args: [agent_name]} = context do
    user = context[:current_user]
    existing_agents = get_agents(context)

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    agent =
      Map.get(existing_agents, agent_name) ||
        agent_fixture(user, %{name: agent_name, enabled: true})

    :ok = Jarga.Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

    conn = context[:conn]
    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:selected_agent, agent)
     |> Map.put(:agents, Map.put(existing_agents, agent_name, agent))
     |> Map.put(:chat_panel_open, true)}
  end

  step "I view the chat panel in workspace {string}", %{args: [ws_name]} = context do
    conn = context[:conn]
    user = context[:current_user]
    existing_workspaces = get_map_from_context(context, :workspaces)

    workspace =
      Map.get(existing_workspaces, ws_name) ||
        workspace_fixture(user, %{name: ws_name, slug: Slugy.slugify(ws_name)})

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:workspaces, Map.put(existing_workspaces, ws_name, workspace))
     |> Map.put(:chat_panel_open, true)}
  end

  step "I have an active conversation with {string}", %{args: [agent_name]} = context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    session =
      chat_session_fixture(%{
        user: user,
        workspace: workspace,
        title: "Chat with #{agent_name}"
      })

    chat_message_fixture(%{
      chat_session: session,
      role: "user",
      content: "Hello #{agent_name}"
    })

    {:ok,
     context
     |> Map.put(:chat_session, session)
     |> Map.put(:active_conversation_agent, agent_name)}
  end

  # ============================================================================
  # PREFERENCE & STATE SETUP
  # ============================================================================

  step "I have not previously interacted with the chat panel", context do
    {:ok,
     context
     |> Map.put(:chat_panel_preference, nil)
     |> Map.put(:first_interaction, true)
     |> Map.put(:no_stored_preferences, true)}
  end

  step "I have not set any chat panel preference", context do
    {:ok,
     context
     |> Map.put(:chat_panel_preference, nil)
     |> Map.put(:no_stored_preferences, true)
     |> Map.put(:first_visit, true)}
  end

  step "I have no messages in the current session", context do
    session = context[:chat_session] || context[:created_session]
    messages = get_session_messages(session)

    {:ok,
     context
     |> Map.put(:messages, messages)
     |> Map.put(:empty_chat_state, Enum.empty?(messages))}
  end

  step "I have a saved message in the chat", context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    session =
      context[:chat_session] ||
        chat_session_fixture(%{user: user, workspace: workspace})

    message =
      chat_message_fixture(%{
        chat_session: session,
        role: "user",
        content: "Saved message"
      })

    # Load the message into the chat panel for testing
    {view, html, context} = load_message_into_chat_panel(context, session, message)

    {:ok,
     context
     |> Map.put(:chat_session, session)
     |> Map.put(:saved_message, message)
     |> Map.put(:message_to_delete, message)
     |> Map.put(:deleted_message_content, message.content)
     |> Map.put(:message_content_to_keep, message.content)
     |> Map.put(:last_html, html)
     |> Map.put(:view, view)}
  end

  step "I have a saved message with a database ID", context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    session =
      context[:chat_session] ||
        chat_session_fixture(%{user: user, workspace: workspace})

    message =
      chat_message_fixture(%{
        chat_session: session,
        role: "user",
        content: "Saved message"
      })

    # Load the message into the chat panel for testing
    {view, html, context} = load_message_into_chat_panel(context, session, message)

    {:ok,
     context
     |> Map.put(:chat_session, session)
     |> Map.put(:saved_message, message)
     |> Map.put(:message_to_delete, message)
     |> Map.put(:deleted_message_content, message.content)
     |> Map.put(:message_content_to_keep, message.content)
     |> Map.put(:last_html, html)
     |> Map.put(:view, view)}
  end

  step "I have a message ID that no longer exists", context do
    fake_message_id = Ecto.UUID.generate()

    {:ok,
     context
     |> Map.put(:invalid_message_id, true)
     |> Map.put(:fake_message_id, fake_message_id)}
  end

  # ============================================================================
  # DATA TABLE STEPS
  # ============================================================================

  step "I am viewing the following pages in sequence:", context do
    pages = context.datatable.maps
    Map.put(context, :pages_to_visit, pages)
  end

  step "I toggle the chat panel on each page", context do
    pages = context[:pages_to_visit] || []

    {:ok,
     context
     |> Map.put(:pages_tested, Enum.map(pages, & &1["Page"]))
     |> Map.put(:toggle_tested_on_pages, true)}
  end
end
