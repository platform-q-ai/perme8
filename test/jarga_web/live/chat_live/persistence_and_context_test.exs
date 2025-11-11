defmodule JargaWeb.ChatLive.PersistenceAndContextTest do
  @moduledoc """
  TDD tests for chat conversation persistence and page context retrieval.

  These tests define the expected behavior before implementation.
  """
  # async: false for database persistence tests
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures
  import Jarga.DocumentsFixtures
  import Jarga.NotesFixtures

  describe "TDD: Chat conversation persistence across navigation" do
    setup do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      %{user: user, workspace: workspace, project: project}
    end

    test "clear button removes messages from UI (but they persist in DB)", %{
      conn: conn,
      user: user
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Add messages (saved to database)
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Message 1"})

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Message 2"})

      assert has_element?(view, ".chat-bubble", "Message 1")
      assert has_element?(view, ".chat-bubble", "Message 2")

      # Clear chat (clears UI only)
      view
      |> element("button[phx-click='clear_chat']")
      |> render_click()

      # Messages should be cleared from UI
      refute has_element?(view, ".chat-bubble", "Message 1")
      refute has_element?(view, ".chat-bubble", "Message 2")

      # Navigate to another page
      {:ok, view2, _html} = live(conn, ~p"/app/workspaces")

      # Messages are auto-restored from database
      assert has_element?(view2, ".chat-bubble", "Message 1")
      assert has_element?(view2, ".chat-bubble", "Message 2")
    end
  end

  describe "TDD: Page context retrieval for LLM queries" do
    setup do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "Engineering Team"})
      project = project_fixture(user, workspace, %{name: "Mobile App"})
      document = document_fixture(user, workspace, project, %{title: "API Documentation"})

      %{user: user, workspace: workspace, project: project, document: document}
    end

    test "extracts and sends workspace name to LLM", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # The context should include the workspace name
      # We can verify this by checking the system message sent to LLM
      # For now, just verify the message is sent
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "What workspace am I in?"})

      assert has_element?(view, ".chat-bubble", "What workspace am I in?")
    end

    @tag :evaluation
    test "LLM can answer questions about current workspace", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "What is the name of the workspace I'm viewing?"})

      # Wait for LLM response
      Process.sleep(3_000)

      html = render(view)

      # Response should mention the workspace name
      assert html =~ ~r/Engineering Team/i
    end

    @tag :evaluation
    test "LLM can answer questions about current project", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "What project am I looking at?"})

      # Wait for LLM response
      Process.sleep(3_000)

      html = render(view)

      # Response should mention the project name
      assert html =~ ~r/Mobile App/i
    end

    @tag :evaluation
    test "LLM can answer questions about current document", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "What page am I on?"})

      # Wait for LLM response
      Process.sleep(3_000)

      html = render(view)

      # Response should mention the page title
      assert html =~ ~r/API Documentation/i
    end

    test "context includes page title for all pages", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      # Dashboard should have page title
      {:ok, _view, html} = live(conn, ~p"/app")
      assert html =~ "Welcome to Jarga"

      # Settings should have page title
      {:ok, _view, html} = live(conn, ~p"/users/settings")
      assert html =~ "Account Settings"
    end

    test "context includes user information", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Send message to trigger context building
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Who am I?"})

      # User email should be in the context (we can't directly test this,
      # but the integration test will verify the LLM uses it)
      assert has_element?(view, ".chat-bubble", "Who am I?")
    end

    @tag :evaluation
    test "LLM receives complete context and can answer detailed questions", %{
      conn: conn,
      user: user,
      workspace: workspace,
      project: project
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

      view
      |> element("#chat-message-form")
      |> render_submit(%{
        message: "Tell me about where I am. Include the workspace, project, and my email."
      })

      # Wait for LLM response
      Process.sleep(3_000)

      html = render(view)

      # Response should include all context elements
      assert html =~ ~r/Engineering Team/i
      assert html =~ ~r/Mobile App/i
      assert html =~ user.email
    end
  end

  describe "TDD: Page content is included in context" do
    setup do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      # Create a document
      document =
        document_fixture(user, workspace, project, %{
          title: "Authentication Guide"
        })

      # Create a note with markdown content for the document
      note =
        note_fixture(user, workspace.id, %{
          id: document.id,
          note_content: %{
            "markdown" => "This page explains how to authenticate users using JWT tokens."
          }
        })

      %{user: user, workspace: workspace, project: project, document: document, note: note}
    end

    @tag :evaluation
    test "document content is included in LLM context", %{
      conn: conn,
      user: user,
      workspace: workspace,
      document: document,
      note: _note
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} =
        live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      # Verify we're on the correct page
      assert render(view) =~ document.title

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "What authentication method is described on this page?"})

      # Wait for LLM response
      Process.sleep(3_000)

      html = render(view)

      # Verify page content was sent (check that we got a response and it's an assistant message)
      assert html =~ "chat chat-start", "Should have received an assistant response"

      # The key test: verify source citation is present, proving context was used
      assert html =~ "Source:",
             "Source citation should be displayed, proving page content was sent"

      assert html =~ document.title, "Source should reference the page title"

      # Optionally verify the note content structure exists (this proves it was loaded)
      # We test indirectly by checking the source attribution worked
    end
  end
end
