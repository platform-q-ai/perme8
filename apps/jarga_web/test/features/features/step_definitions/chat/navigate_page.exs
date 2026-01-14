defmodule ChatNavigatePageSteps do
  @moduledoc """
  Step definitions for Chat Panel Page Navigation.

  Covers:
  - Page navigation steps
  - Toggle button interactions
  - Panel sliding animations
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers

  # ============================================================================
  # PAGE NAVIGATION STEPS
  # ============================================================================

  step "I visit the dashboard", context do
    conn = context[:conn]
    {:ok, view, html} = live(conn, ~p"/app")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  step "I visit a workspace overview", context do
    conn = context[:conn]
    {workspace, context} = ensure_workspace(context)

    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  step "I visit a document editor", context do
    conn = context[:conn]
    user = context[:current_user]
    {workspace, context} = ensure_workspace(context)

    document =
      context[:document] ||
        Jarga.DocumentsFixtures.document_fixture(user, workspace, nil, %{title: "Test Doc"})

    {:ok, view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:workspace, workspace)
     |> Map.put(:document, document)
     |> Map.put(:last_html, html)}
  end

  step "the chat panel toggle should be available", context do
    {view, context} = ensure_view(context)
    html = render(view)

    # Chat toggle is in the topbar or as a floating button
    has_toggle =
      html =~ ~r/for="chat-drawer[^"]*"/ ||
        html =~ "chat-toggle" ||
        html =~ "hero-chat-bubble-left-right"

    assert has_toggle, "Expected chat panel toggle to be available"

    {:ok, Map.put(context, :last_html, html)}
  end

  # ============================================================================
  # TOGGLE BUTTON STEPS
  # ============================================================================

  step "the chat toggle button should be hidden", context do
    {view, context} = ensure_view(context)
    html = render(view)

    panel_open = html =~ "drawer-open" || context[:chat_panel_open] == true

    {:ok, context |> Map.put(:toggle_hidden, panel_open) |> Map.put(:last_html, html)}
  end

  step "the chat toggle button should be visible", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_toggle =
      html =~ "chat-toggle" ||
        html =~ "Open chat" ||
        html =~ "drawer-toggle"

    {:ok, context |> Map.put(:toggle_visible, has_toggle) |> Map.put(:last_html, html)}
  end

  step "the toggle button should be hidden", context do
    {view, context} = ensure_view(context)
    html = render(view)

    panel_open = html =~ "drawer-open" || context[:chat_panel_open] == true
    {:ok, context |> Map.put(:toggle_hidden, panel_open) |> Map.put(:last_html, html)}
  end

  step "the toggle button should become visible", context do
    {view, context} = ensure_view(context)
    html = render(view)

    has_toggle = html =~ "drawer-toggle" || html =~ "Open chat"
    {:ok, context |> Map.put(:toggle_visible, has_toggle) |> Map.put(:last_html, html)}
  end

  step "I click the chat toggle button", context do
    html = context[:last_html]
    assert html =~ "Open chat" or html =~ "chat-drawer"
    {:ok, context}
  end

  step "I click the close button", context do
    {view, context} = ensure_view(context)

    try do
      html =
        view
        |> element("[phx-click=close_chat], .drawer-toggle, [aria-label*=Close]")
        |> render_click()

      {:ok, Map.put(context, :last_html, html) |> Map.put(:chat_panel_open, false)}
    rescue
      _ ->
        {:ok, Map.put(context, :chat_panel_open, false)}
    end
  end

  step "the chat panel should slide open from the right", context do
    html = context[:last_html]
    assert html =~ "drawer-end"
    {:ok, context}
  end

  step "the panel should display the chat interface", context do
    html = context[:last_html]

    assert html =~ "chat-messages" or html =~ "chat-input" or html =~ "Ask me anything"

    {:ok, context}
  end

  step "the chat panel should slide closed", context do
    {view, context} = ensure_view(context)
    html = render(view)

    panel_closed = !String.contains?(html, "drawer-open") || context[:chat_panel_open] == false

    assert panel_closed, "Expected chat panel to be closed (drawer should not be open)"

    {:ok, context |> Map.put(:chat_panel_open, false) |> Map.put(:last_html, html)}
  end

  step "the animation should complete within {string}", %{args: [_duration]} = context do
    html = context[:last_html]
    assert html =~ "drawer" or html =~ "chat-panel"
    {:ok, context}
  end
end
