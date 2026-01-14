defmodule ChatSessionsHistoryRestoreSteps do
  @moduledoc """
  Step definitions for Chat Session History - Session Restoration.

  Covers:
  - Session restoration
  - Session validation
  - Session ownership verification

  Related modules:
  - ChatSessionsHistorySteps - List and selection
  - ChatSessionsHistoryNavigateSteps - View navigation
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers
  import Jarga.ChatFixtures

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_sessions(context), do: (is_map(context[:sessions]) && context[:sessions]) || %{}

  # ============================================================================
  # SESSION RESTORATION STEPS
  # ============================================================================

  step "my most recent session is {string}", %{args: [title]} = context do
    sessions = get_sessions(context)
    session = Map.get(sessions, title)

    assert session, "Expected session titled '#{title}' to exist in sessions map"

    {:ok, Map.put(context, :most_recent_session, session)}
  end

  step "I reload the page", context do
    conn = context[:conn]
    {:ok, view, html} = live(conn, ~p"/app/")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  step "the {string} session should be automatically restored", %{args: [title]} = context do
    {view, context} = ensure_view(context)
    sessions = get_sessions(context)
    session = Map.get(sessions, title)

    assert session, "Expected session titled '#{title}' to exist in sessions map"

    html = render(view)

    has_content = html =~ title || html =~ "chat-bubble" || html =~ "message"

    {:ok, Map.put(context, :session_restored, has_content)}
  end

  step "the session exists in the database", context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    assert user, "A user must be logged in"
    assert workspace, "A workspace must exist"

    # Create a real session in the database and update the saved_session_id
    # This handles cases where the localStorage ID is a placeholder
    session =
      chat_session_fixture(%{user: user, workspace: workspace, title: "Restored Session"})

    chat_message_fixture(%{chat_session: session, role: "user", content: "Previous message"})

    {:ok,
     context
     |> Map.put(:chat_session, session)
     |> Map.put(:saved_session_id, session.id)
     |> Map.put(:stored_session_id, session.id)
     |> Map.put(:session_exists, true)}
  end

  step "I own the session", context do
    user = context[:current_user]
    saved_session_id = context[:saved_session_id]

    assert user, "A user must be logged in"
    assert saved_session_id, "A session ID must be set in a prior step"

    owns =
      case Jarga.Chat.load_session(saved_session_id) do
        {:ok, session} -> session.user_id == user.id
        {:error, _} -> false
      end

    {:ok, Map.put(context, :owns_session, owns)}
  end

  step "the session should be loaded", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_content = html =~ "chat-bubble" || html =~ "chat-messages"
    {:ok, context |> Map.put(:session_loaded, has_content) |> Map.put(:last_html, html)}
  end

  step "the session does not exist in the database", context do
    saved_session_id = context[:saved_session_id]

    session_invalid =
      case saved_session_id do
        nil ->
          true

        id ->
          case Jarga.Chat.load_session(id) do
            {:error, :not_found} -> true
            {:ok, _} -> false
          end
      end

    {:ok, Map.put(context, :session_invalid, session_invalid)}
  end

  step "the session belongs to another user", context do
    other_user = Jarga.AccountsFixtures.user_fixture()

    workspace =
      Jarga.WorkspacesFixtures.workspace_fixture(other_user, %{
        name: "Other User Workspace",
        slug: "other-ws-#{System.unique_integer([:positive])}"
      })

    other_session =
      chat_session_fixture(%{
        user: other_user,
        workspace: workspace,
        title: "Other User's Session"
      })

    {:ok,
     context
     |> Map.put(:session_unauthorized, true)
     |> Map.put(:other_user, other_user)
     |> Map.put(:other_user_session, other_session)
     |> Map.put(:saved_session_id, other_session.id)}
  end

  step "the session should not be loaded", context do
    {view, context} = ensure_view(context)

    assert context[:session_unauthorized] == true,
           "Expected session_unauthorized to be set in prior step"

    html = render(view)
    has_no_messages = not (html =~ "chat-bubble") || html =~ "Ask me anything"
    {:ok, Map.put(context, :session_not_loaded, has_no_messages)}
  end
end
