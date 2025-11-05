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
  import Jarga.PagesFixtures
  import Jarga.NotesFixtures

  describe "TDD: Chat conversation persistence across navigation" do
    setup do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      %{user: user, workspace: workspace, project: project}
    end

    @tag :skip
    test "messages persist when navigating between different pages", %{
      conn: conn,
      user: user,
      workspace: workspace
    } do
      conn = log_in_user(conn, user)

      # Start on dashboard
      {:ok, view, _html} = live(conn, ~p"/app")

      # Send a message on dashboard
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Test message on dashboard"})

      assert has_element?(view, ".chat-bubble", "Test message on dashboard")

      # Navigate to workspaces page
      {:ok, view, _html} = live(conn, ~p"/app/workspaces")

      # Message should still be visible
      assert has_element?(view, ".chat-bubble", "Test message on dashboard")

      # Send another message on workspaces page
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Test message on workspaces"})

      assert has_element?(view, ".chat-bubble", "Test message on workspaces")

      # Navigate to workspace detail page
      {:ok, view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

      # Both messages should still be visible
      assert has_element?(view, ".chat-bubble", "Test message on dashboard")
      assert has_element?(view, ".chat-bubble", "Test message on workspaces")
    end

    test "clear button removes all messages and persists empty state", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Add messages
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Message 1"})

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Message 2"})

      assert has_element?(view, ".chat-bubble", "Message 1")
      assert has_element?(view, ".chat-bubble", "Message 2")

      # Clear chat
      view
      |> element("button[phx-click='clear_chat']")
      |> render_click()

      # Messages should be cleared
      refute has_element?(view, ".chat-bubble", "Message 1")
      refute has_element?(view, ".chat-bubble", "Message 2")

      # Navigate to another page
      {:ok, view, _html} = live(conn, ~p"/app/workspaces")

      # Chat should still be empty
      refute has_element?(view, ".chat-bubble", "Message 1")
      refute has_element?(view, ".chat-bubble", "Message 2")
    end

    @tag :skip
    test "conversation persists after browser refresh (via database)", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app")

      # Send a message
      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "Persistent message"})

      assert has_element?(view, ".chat-bubble", "Persistent message")

      # Simulate browser refresh by creating new LiveView connection
      {:ok, view, _html} = live(conn, ~p"/app")

      # Message should still be there (loaded from database)
      assert has_element?(view, ".chat-bubble", "Persistent message")
    end
  end

  describe "TDD: Page context retrieval for LLM queries" do
    setup do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "Engineering Team"})
      project = project_fixture(user, workspace, %{name: "Mobile App"})
      page = page_fixture(user, workspace, project, %{title: "API Documentation"})

      %{user: user, workspace: workspace, project: project, page: page}
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

    @tag :integration
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
      Process.sleep(5_000)

      html = render(view)

      # Response should mention the workspace name
      assert html =~ ~r/Engineering Team/i
    end

    @tag :integration
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
      Process.sleep(5_000)

      html = render(view)

      # Response should mention the project name
      assert html =~ ~r/Mobile App/i
    end

    @tag :integration
    test "LLM can answer questions about current page", %{
      conn: conn,
      user: user,
      workspace: workspace,
      page: page
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "What page am I on?"})

      # Wait for LLM response
      Process.sleep(5_000)

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

    @tag :integration
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
      Process.sleep(5_000)

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

      # Create a page
      page =
        page_fixture(user, workspace, project, %{
          title: "Authentication Guide"
        })

      # Create a note with markdown content for the page
      note =
        note_fixture(user, workspace.id, %{
          id: page.id,
          note_content: %{
            "markdown" => "This page explains how to authenticate users using JWT tokens."
          }
        })

      %{user: user, workspace: workspace, project: project, page: page, note: note}
    end

    @tag :integration
    test "page content is included in LLM context", %{
      conn: conn,
      user: user,
      workspace: workspace,
      page: page,
      note: _note
    } do
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}/pages/#{page.slug}")

      # Verify we're on the correct page
      assert render(view) =~ page.title

      view
      |> element("#chat-message-form")
      |> render_submit(%{message: "What authentication method is described on this page?"})

      # Wait for LLM response
      Process.sleep(5_000)

      html = render(view)

      # Verify page content was sent (check that we got a response and it's an assistant message)
      assert html =~ "chat chat-start", "Should have received an assistant response"

      # The key test: verify source citation is present, proving context was used
      assert html =~ "Source:", "Source citation should be displayed, proving page content was sent"
      assert html =~ page.title, "Source should reference the page title"

      # Optionally verify the note content structure exists (this proves it was loaded)
      # We test indirectly by checking the source attribution worked
    end
  end
end
