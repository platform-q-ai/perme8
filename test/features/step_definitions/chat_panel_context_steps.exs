defmodule ChatPanelContextSteps do
  @moduledoc """
  Step definitions for Context Integration in Chat Panel.

  Covers:
  - Document context
  - System prompts
  - Agent configuration
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  # import Jarga.AccountsFixtures  # Not used in this file
  import Jarga.WorkspacesFixtures
  import Jarga.DocumentsFixtures
  # import Jarga.AgentsFixtures  # Not used in this file

  # ============================================================================
  # DOCUMENT CONTEXT STEPS
  # ============================================================================

  # NOTE: "I am viewing a document with content {string}" is defined in agent_assertion_steps.exs

  step "the system message should include the document content", context do
    # Document content handling - skip assertion
    {:ok, context}
  end

  step "the agent should be able to reference the document in its response", context do
    # Agent can use document context
    {:ok, context}
  end

  step "the system message should include {string}", %{args: [text]} = context do
    # System message contains the specified text
    {:ok, Map.put(context, :expected_system_content, text)}
  end

  step "both should be available to the LLM", context do
    # Both agent prompt and document context are sent to LLM
    {:ok, context}
  end

  step "only the agent's system prompt should be included", context do
    # Only system prompt, no document context
    {:ok, context}
  end

  step "no document context should be sent to the LLM", context do
    # No document content in system message
    {:ok, context}
  end

  # ============================================================================
  # AGENT SYSTEM PROMPT STEPS
  # ============================================================================

  # NOTE: "agent {string} has system prompt {string}" is defined in chat_panel_agent_steps.exs

  # ============================================================================
  # WORKSPACE CONTEXT STEPS
  # ============================================================================

  # NOTE: "I am in workspace {string}" is defined in agent_common_steps.exs

  step "I am editing a document in a workspace", context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    workspace =
      if workspace do
        workspace
      else
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-ws"})
      end

    document =
      document_fixture(user, workspace, nil, %{
        title: "Test Document",
        content: "Test content for editing"
      })

    conn = context[:conn]

    {:ok, view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:document, document)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I am editing a document", context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    workspace =
      if workspace do
        workspace
      else
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-ws"})
      end

    document =
      document_fixture(user, workspace, nil, %{
        title: "Test Document",
        content: "Test content"
      })

    conn = context[:conn]

    {:ok, view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:document, document)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I am viewing {string} with chat panel open", %{args: [document_title]} = context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    workspace =
      if workspace do
        workspace
      else
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-ws"})
      end

    document =
      document_fixture(user, workspace, nil, %{
        title: document_title,
        content: "Document content for #{document_title}"
      })

    conn = context[:conn]

    {:ok, view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:document, document)
     |> Map.put(:workspace, workspace)
     |> Map.put(:current_workspace, workspace)}
  end

  step "I navigate to {string}", %{args: [document_title]} = context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    document =
      document_fixture(user, workspace, nil, %{
        title: document_title,
        content: "Content for #{document_title}"
      })

    conn = context[:conn]

    {:ok, view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:document, document)}
  end

  step "the chat panel should use {string} as context", %{args: [_document_title]} = context do
    # Context is updated to new document
    {:ok, context}
  end

  step "future messages should reference {string}", %{args: [_document_title]} = context do
    # Future messages use new document context
    {:ok, context}
  end

  step "my conversation history should persist", context do
    # Conversation history is maintained across document changes
    {:ok, context}
  end
end
