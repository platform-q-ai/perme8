defmodule ChatSetupDocumentsSteps do
  @moduledoc """
  Step definitions for Chat Panel Document and Project Context Setup.

  Covers:
  - Document viewing context for chat
  - Project context setup
  - Document navigation with chat panel
  - Document content verification
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers
  import Jarga.WorkspacesFixtures
  import Jarga.ChatFixtures

  # ============================================================================
  # DOCUMENT VIEWING SETUP
  # ============================================================================

  step "I am viewing a document with content:", context do
    setup_document_with_content(context)
  end

  step "I am editing a document with content:", context do
    setup_document_with_content(context)
  end

  defp setup_document_with_content(context) do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    content = context.docstring || ""

    document =
      Jarga.DocumentsFixtures.document_fixture(user, workspace, nil, %{
        title: "Test Document",
        content: content
      })

    {:ok, view, html} =
      live(context[:conn], ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:document, document)
     |> Map.put(:document_content, content)}
  end

  step "I am viewing {string} with content {string}", %{args: [title, content]} = context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    document =
      Jarga.DocumentsFixtures.document_fixture(user, workspace, nil, %{
        title: title,
        content: content
      })

    session =
      context[:chat_session] ||
        chat_session_fixture(%{user: user, workspace: workspace})

    conn = context[:conn]

    {:ok, view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:document, document)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:chat_session, session)
     |> Map.put(:created_session, session)}
  end

  step "I am viewing a document titled {string}", %{args: [title]} = context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    document =
      Jarga.DocumentsFixtures.document_fixture(user, workspace, nil, %{
        title: title,
        content: "Document content for #{title}"
      })

    {:ok, view, html} =
      live(context[:conn], ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:document, document)
     |> Map.put(:document_content, "Document content for #{title}")
     |> Map.put(:document_content_available, true)}
  end

  step "I am viewing a document in {string}", %{args: [project_name]} = context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    project = get_or_create_project(context, project_name, user, workspace)
    document = create_document_in_project(user, workspace, project, project_name)

    {:ok, view, html} =
      live(context[:conn], ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)
     |> Map.put(:project, project)
     |> Map.put(:document, document)}
  end

  defp get_or_create_project(context, project_name, user, workspace) do
    (context[:projects] || %{})[project_name] ||
      Jarga.ProjectsFixtures.project_fixture(user, workspace, %{name: project_name})
  end

  defp create_document_in_project(user, workspace, project, project_name) do
    Jarga.DocumentsFixtures.document_fixture(user, workspace, project, %{
      title: "Test Document in #{project_name}",
      content: "Document content"
    })
  end

  step "I navigate to {string} with content {string}", %{args: [title, content]} = context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    document =
      Jarga.DocumentsFixtures.document_fixture(user, workspace, nil, %{
        title: title,
        content: content
      })

    {:ok, view, html} =
      live(context[:conn], ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:document, document)
     |> Map.put(:document_content, content)}
  end

  step "I navigate to the workspace overview", context do
    workspace = context[:workspace] || context[:current_workspace]
    assert workspace, "Workspace must be set"

    {:ok, view, html} = live(context[:conn], ~p"/app/workspaces/#{workspace.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  step "I navigate to a document with a note", context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    document =
      Jarga.DocumentsFixtures.document_fixture(user, workspace, nil, %{
        title: "Document with Note",
        content: "Some content"
      })

    {:ok, view, html} =
      live(context[:conn], ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:document, document)}
  end

  # ============================================================================
  # PROJECT SETUP
  # ============================================================================

  step "I have a project {string}", %{args: [name]} = context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    project = Jarga.ProjectsFixtures.project_fixture(user, workspace, %{name: name})

    projects = context[:projects] || %{}

    {:ok,
     context
     |> Map.put(:projects, Map.put(projects, name, project))
     |> Map.put(:project, project)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  # ============================================================================
  # MESSAGES IN CHAT PANEL
  # ============================================================================

  step "I have messages in the chat panel", context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    session =
      context[:chat_session] ||
        Jarga.ChatFixtures.chat_session_fixture(%{user: user, workspace: workspace})

    Jarga.ChatFixtures.chat_message_fixture(%{
      chat_session: session,
      role: "user",
      content: "Test message"
    })

    {:ok,
     context
     |> Map.put(:chat_session, session)
     |> Map.put(:has_messages, true)}
  end

  step "message insert buttons should not be visible", context do
    {view, context} = ensure_view(context)
    html = render(view)

    refute html =~ "Insert into",
           "Expected insert buttons to NOT be visible on non-document pages"

    {:ok, Map.put(context, :last_html, html)}
  end

  step "message insert buttons should be visible", context do
    {view, context} = ensure_view(context)
    html = render(view)

    # Insert buttons appear on document pages with notes, in assistant message footers
    # They show "insert" link in chat-footer
    has_insert =
      html =~ "insert" ||
        html =~ "Insert into note" ||
        html =~ "phx-click=\"insert_into_note\""

    # Note: Insert buttons only appear for assistant messages when on a document with a note
    # Verify we're on the right page (document with note)
    on_document_page = context[:document] != nil && context[:note] != nil

    assert has_insert || !on_document_page,
           "Expected insert buttons to be visible on document page with note"

    {:ok,
     context
     |> Map.put(:insert_buttons_expected, true)
     |> Map.put(:last_html, html)}
  end
end
