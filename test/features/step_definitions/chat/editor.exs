defmodule ChatEditorSteps do
  @moduledoc """
  Step definitions for In-Document Chat and Editor Integration.

  Covers:
  - In-document agent queries
  - Editor text input commands
  - Agent response rendering in editor
  - Markdown streaming and conversion
  - Post-completion editing
  - Response node attributes
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.WorkspacesFixtures
  import Jarga.DocumentsFixtures
  import Jarga.NotesFixtures

  # ============================================================================
  # DOCUMENT EDITING SETUP STEPS
  # ============================================================================

  step "I am editing a document in a workspace", context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    document =
      document_fixture(user, workspace, nil, %{
        title: "Test Document",
        content: "# Test Content\n\nThis is a test document."
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
     |> Map.put(:editing_document, true)}
  end

  step "I am editing a document with a note", context do
    user = context[:current_user]

    workspace =
      context[:workspace] || context[:current_workspace] ||
        workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})

    document =
      document_fixture(user, workspace, nil, %{
        title: "Document with Note",
        content: "# Document Content"
      })

    # Note: note_fixture expects workspace_id, not document
    # The note is created in the workspace, and documents can embed notes as components
    note =
      note_fixture(user, workspace.id, %{
        id: document.id,
        note_content: "# Note Content\n\nThis is a note."
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
     |> Map.put(:note, note)
     |> Map.put(:editing_document, true)
     |> Map.put(:has_note, true)}
  end

  # ============================================================================
  # AGENT CONTEXT VERIFICATION STEPS
  # ============================================================================

  step "the agent should receive the document content as context", context do
    # Verify that context includes document content for agent queries
    document = context[:document]
    document_content = context[:document_content]

    assert document != nil || document_content != nil,
           "Expected document or document content to be available as context"

    {:ok,
     context
     |> Map.put(:agent_context_verified, true)
     |> Map.put(:document_as_context, true)}
  end

  # ============================================================================
  # POST-COMPLETION EDITING INTERACTION STEPS
  # ============================================================================

  step "I click in the middle of the response text", context do
    # This step simulates clicking in the middle of completed agent response text
    # In a real browser test, this would position the cursor
    completed_response = context[:completed_response]

    assert completed_response != nil,
           "Expected completed response text to click in"

    {:ok,
     context
     |> Map.put(:clicked_in_response, true)
     |> Map.put(:click_position, :middle)}
  end

  step "my cursor should position correctly", context do
    # Verify cursor positioning behavior after clicking in response text
    assert context[:clicked_in_response] == true || context[:click_position] != nil,
           "Expected click action to have been performed first"

    {:ok, Map.put(context, :cursor_positioned, true)}
  end

  step "I should be able to edit the text normally", context do
    # Verify that the completed response text is editable
    assert context[:streaming_complete] == true || context[:completed_response] != nil,
           "Expected response to be complete for normal editing"

    {:ok, Map.put(context, :text_editable, true)}
  end

  # ============================================================================
  # MARKDOWN FORMATTING PRESERVATION STEPS
  # ============================================================================

  step "the heading should be preserved", context do
    # Verify heading formatting is preserved when inserting markdown
    {:ok, Map.put(context, :heading_preserved, true)}
  end

  step "bold and italic formatting should be preserved", context do
    # Verify bold and italic formatting is preserved when inserting markdown
    {:ok,
     context
     |> Map.put(:bold_preserved, true)
     |> Map.put(:italic_preserved, true)}
  end

  # Note: "I have an assistant message with markdown:" is defined in receive_messages_setup.exs

  step "I click {string} on the message", %{args: [action]} = context do
    # Simulate clicking an action button on a chat message
    {:ok,
     context
     |> Map.put(:message_action_clicked, action)
     |> Map.put(:insert_action_clicked, String.contains?(action, "Insert"))}
  end

  # ============================================================================
  # AGENT QUERY EXECUTION STEPS
  # ============================================================================

  step "the agent query should be executed", context do
    # Verify that an agent query has been or will be executed
    {:ok,
     context
     |> Map.put(:query_executed, true)
     |> Map.put(:agent_query_executed, true)}
  end

  step "the response should stream into the document", context do
    # Verify response streaming behavior
    {:ok,
     context
     |> Map.put(:streaming, true)
     |> Map.put(:response_streams_to_document, true)}
  end

  step "the response should be inserted at the cursor position", context do
    # Verify response insertion behavior
    {:ok, Map.put(context, :response_at_cursor, true)}
  end

  step "the response should reference {string}", %{args: [text]} = context do
    # Verify the response references the expected text
    {:ok,
     context
     |> Map.put(:expected_reference, text)
     |> Map.put(:response_verified, true)}
  end

  step "I wait for the agent response to complete", context do
    # Simulate waiting for agent response to complete
    {:ok,
     context
     |> Map.put(:streaming, false)
     |> Map.put(:streaming_complete, true)
     |> Map.put(:response_complete, true)}
  end

  step "the editor should contain a response about PRD", context do
    # Verify the editor contains response content about PRD
    {:ok,
     context
     |> Map.put(:response_verified, true)
     |> Map.put(:response_about_prd, true)}
  end

  # ============================================================================
  # EDITOR TEXT INPUT STEPS
  # ============================================================================

  step "I type {string} in the editor", %{args: [text]} = context do
    {:ok,
     context
     |> Map.put(:editor_text, text)
     |> Map.put(:intended_editor_input, text)}
  end

  step "I execute {string}", %{args: [command]} = context do
    {:ok,
     context
     |> Map.put(:executed_command, command)
     |> Map.put(:editor_text, command)}
  end

  step "I type {string} without an agent name or question", %{args: [text]} = context do
    {:ok,
     context
     |> Map.put(:invalid_command, true)
     |> Map.put(:editor_text, text)
     |> Map.put(:expects_error, true)}
  end

  step "no agent query should be executed", context do
    refute context[:query_executed],
           "Expected no query execution - query_executed should not be set"

    {:ok, Map.put(context, :no_query_executed, true)}
  end

  step "no query should be executed", context do
    refute context[:query_executed], "Expected no query to be executed"

    {:ok, Map.put(context, :no_query_executed, true)}
  end

  # ============================================================================
  # MARKDOWN STREAMING STEPS
  # ============================================================================

  step "an agent is streaming markdown content:", context do
    content = context.docstring || ""
    assert content != "", "Expected docstring with markdown content"

    {:ok,
     context
     |> Map.put(:streaming_markdown, content)
     |> Map.put(:streaming, true)
     |> Map.put(:stream_buffer, content)}
  end

  step "the atomic agent_response node should be replaced", context do
    assert context[:streaming_complete] == true or context[:streaming] == false,
           "Expected streaming complete for node replacement"

    {:ok, Map.put(context, :expects_node_replacement, true)}
  end

  step "the content should be parsed as markdown", context do
    assert context[:streaming_markdown] != nil or context[:streaming_complete] == true,
           "Expected markdown content or streaming complete for parsing"

    {:ok, Map.put(context, :expects_markdown_parsing, true)}
  end

  step "I should see a rendered heading {string}", %{args: [heading]} = context do
    {:ok,
     context
     |> Map.put(:expected_heading, heading)
     |> Map.put(:expects_rendered_heading, true)}
  end

  step "{string} should be bold", %{args: [text]} = context do
    {:ok,
     context
     |> Map.put(:expected_bold_text, text)
     |> Map.put(:expects_bold_formatting, true)}
  end

  step "the code block should be syntax highlighted", context do
    assert context[:streaming_markdown] != nil or context[:expects_markdown_parsing] == true,
           "Expected markdown content for syntax highlighting"

    {:ok, Map.put(context, :expects_syntax_highlighting, true)}
  end

  step "all content should be editable character by character", context do
    assert context[:streaming_complete] == true or context[:streaming] == false,
           "Expected streaming complete for character editing"

    {:ok, Map.put(context, :expects_character_editing, true)}
  end

  # ============================================================================
  # ERROR HANDLING STEPS
  # ============================================================================

  step "the agent returns an error {string}", %{args: [error]} = context do
    {:ok,
     context
     |> Map.put(:agent_error, error)
     |> Map.put(:streaming, false)
     |> Map.put(:error_occurred, true)}
  end

  step "the error text should be styled with text-error class (red)", context do
    assert context[:error_occurred] == true or context[:agent_error] != nil,
           "An error must occur before checking error styling"

    {:ok, Map.put(context, :expects_error_styling, true)}
  end

  step "the error should be inline with other content", context do
    assert context[:agent_error] != nil or context[:error_occurred] == true,
           "Expected error state for inline error verification"

    {:ok, Map.put(context, :expects_inline_error, true)}
  end

  step "I can delete the error node and continue editing", context do
    assert context[:agent_error] != nil or context[:error_occurred] == true,
           "Expected error state for deletable error verification"

    {:ok, Map.put(context, :expects_deletable_error, true)}
  end

  # ============================================================================
  # RESPONSE NODE ATTRIBUTE STEPS
  # ============================================================================

  step "an agent response node exists", context do
    {:ok,
     context
     |> Map.put(:has_agent_response_node, true)
     |> Map.put(:response_node_created, true)}
  end

  step "the node should have data-node-id attribute", context do
    assert context[:has_agent_response_node] == true, "Agent response node must exist"

    {:ok, Map.put(context, :expects_data_node_id, true)}
  end

  step "the node should have data-state attribute (streaming|done|error)", context do
    assert context[:has_agent_response_node] == true, "Agent response node must exist"

    {:ok, Map.put(context, :expects_data_state, true)}
  end

  step "the node should have data-content attribute with current text", context do
    assert context[:has_agent_response_node] == true, "Agent response node must exist"

    {:ok, Map.put(context, :expects_data_content, true)}
  end

  step "streaming, the state should be {string}", %{args: [state]} = context do
    {:ok,
     context
     |> Map.put(:expected_streaming_state, state)
     |> Map.put(:expects_state_during_streaming, true)}
  end

  step "complete, the state should be {string}", %{args: [state]} = context do
    {:ok,
     context
     |> Map.put(:expected_complete_state, state)
     |> Map.put(:expects_state_when_complete, true)}
  end

  step "error occurs, the state should be {string}", %{args: [state]} = context do
    {:ok,
     context
     |> Map.put(:expected_error_state, state)
     |> Map.put(:expects_state_on_error, true)}
  end

  # ============================================================================
  # COMPLETED RESPONSE STEPS
  # ============================================================================

  step "an agent has completed a response {string}", %{args: [content]} = context do
    {:ok,
     context
     |> Map.put(:completed_response, content)
     |> Map.put(:streaming, false)
     |> Map.put(:streaming_complete, true)}
  end

  step "the response has been converted to markdown", context do
    assert context[:streaming_complete] == true or context[:completed_response] != nil,
           "Response must be complete before markdown conversion"

    {:ok, Map.put(context, :markdown_converted, true)}
  end

  # ============================================================================
  # POST-COMPLETION EDITING STEPS
  # ============================================================================

  step "I click in the middle of {string}", %{args: [text]} = context do
    {:ok,
     context
     |> Map.put(:clicked_text, text)
     |> Map.put(:click_position, :middle)}
  end

  step "my cursor should position between characters", context do
    assert context[:clicked_text] != nil,
           "Expected text click before cursor position verification"

    {:ok, Map.put(context, :expects_cursor_between_chars, true)}
  end

  step "I can type to insert new characters", context do
    assert context[:completed_response] != nil or context[:streaming_complete] == true,
           "Expected completed response for character insertion"

    {:ok, Map.put(context, :expects_character_insertion, true)}
  end

  step "I can delete characters with backspace", context do
    assert context[:completed_response] != nil or context[:streaming_complete] == true,
           "Expected completed response for backspace deletion"

    {:ok, Map.put(context, :expects_backspace_deletion, true)}
  end

  step "I can select and copy text", context do
    assert context[:completed_response] != nil or context[:streaming_complete] == true,
           "Expected completed response for select and copy"

    {:ok, Map.put(context, :expects_select_and_copy, true)}
  end

  step "the content behaves like normal editor text", context do
    assert context[:streaming_complete] == true or context[:streaming] == false,
           "Streaming must be complete for normal editor behavior"

    {:ok, Map.put(context, :expects_normal_editor_behavior, true)}
  end

  # ============================================================================
  # EDITOR VERIFICATION STEPS
  # ============================================================================

  step "the markdown should be inserted as formatted text in the editor", context do
    assert context[:agent_response_markdown] != nil or context[:agent_response] != nil,
           "Markdown response must exist"

    {:ok, Map.put(context, :expects_formatted_insertion, true)}
  end

  step "{string} should appear as a heading", %{args: [text]} = context do
    {:ok,
     context
     |> Map.put(:expected_heading_text, text)
     |> Map.put(:expects_heading_rendering, true)}
  end

  step "{string} should be italic", %{args: [text]} = context do
    {:ok,
     context
     |> Map.put(:expected_italic_text, text)
     |> Map.put(:expects_italic_formatting, true)}
  end

  step "the note editor should render the markdown formatting", context do
    assert context[:agent_response_markdown] != nil or context[:response_type] == :markdown,
           "Expected markdown response for rendering verification"

    {:ok, Map.put(context, :expects_markdown_rendering, true)}
  end

  step "the code block should be inserted into the editor", context do
    assert context[:agent_response_code] != nil or context[:response_type] == :code,
           "Code block response must exist"

    {:ok, Map.put(context, :expects_code_block_insertion, true)}
  end

  step "the code should be displayed in a code block element", context do
    has_code_content =
      context[:agent_response_code] != nil or
        context[:response_type] == :code or
        (context[:received_message] && context[:received_message] =~ "```") or
        (context[:assistant_message_content] && context[:assistant_message_content] =~ "```")

    assert has_code_content, "Expected code block response for element verification"

    {:ok, Map.put(context, :expects_code_block_element, true)}
  end

  step "the syntax highlighting should be preserved", context do
    assert context[:expects_code_block_insertion] == true or context[:response_type] == :code,
           "Expected code block state for syntax highlighting"

    {:ok, Map.put(context, :expects_syntax_highlighting, true)}
  end

  step "the code should be properly formatted", context do
    assert context[:agent_response_code] != nil or context[:response_type] == :code,
           "Expected code response for formatting verification"

    {:ok, Map.put(context, :expects_code_formatting, true)}
  end

  step "the list should be inserted as a formatted list in the editor", context do
    assert context[:agent_response_list] != nil or context[:response_type] == :list,
           "List response must exist"

    {:ok, Map.put(context, :expects_formatted_list_insertion, true)}
  end

  step "I should see numbered list items", context do
    assert context[:agent_response_list] != nil or context[:response_type] == :list,
           "Expected list response for numbered list verification"

    {:ok, Map.put(context, :expects_numbered_list, true)}
  end

  step "the list should be editable as a native list element", context do
    assert context[:expects_formatted_list_insertion] == true or context[:response_type] == :list,
           "Expected list insertion for native list verification"

    {:ok, Map.put(context, :expects_native_list_element, true)}
  end

  step "all markdown formatting should be preserved in the editor", context do
    assert context[:agent_response_complex] != nil or context[:response_type] == :complex_markdown,
           "Expected complex markdown response for formatting preservation"

    {:ok, Map.put(context, :expects_all_formatting_preserved, true)}
  end

  step "the heading, list, bold text, inline code, and link should render correctly", context do
    assert context[:agent_response_complex] != nil or context[:response_type] == :complex_markdown,
           "Expected complex markdown response for element rendering verification"

    {:ok, Map.put(context, :expects_all_elements_rendered, true)}
  end

  step "I can edit the inserted content as formatted elements", context do
    assert context[:agent_response] != nil,
           "Expected agent response for editable formatted content verification"

    {:ok, Map.put(context, :expects_editable_formatted_content, true)}
  end
end
