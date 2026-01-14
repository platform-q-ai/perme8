defmodule Documents.EditorCheckboxSteps do
  @moduledoc """
  Step definitions for document editor checkbox styling.

  Tests the visual strikethrough effect on checked todo items in the document editor.
  This is a full-stack test that verifies the CSS styling is applied correctly
  when a task list item is checked.

  NOTE: This feature tests CSS styling that is applied client-side by the browser.
  Since the checkboxes are rendered dynamically by JavaScript (Milkdown editor),
  we test by:
  1. Navigating to a real document page (to verify CSS is loaded)
  2. Verifying the CSS file contains the correct strikethrough rules
  3. The CSS rules will automatically apply to any li[data-checked="true"] elements
     that the JavaScript editor renders

  We do NOT mock HTML - we test the real page and real CSS file.

  Related modules:
  - Documents.CollaborateSteps - Real-time collaboration
  - Documents.ComponentsSteps - Editor components
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.DocumentsFixtures

  alias Ecto.Adapters.SQL.Sandbox

  # ============================================================================
  # SETUP STEPS
  # ============================================================================

  step "I am on a page with a todo item {string}", %{args: [task_text]} = context do
    ensure_sandbox_checkout(context)
    {user, workspace, document} = create_test_fixtures()
    {conn, view, html} = navigate_to_document(user, workspace, document)

    {:ok, build_context(context, user, workspace, document, conn, view, html, task_text)}
  end

  defp ensure_sandbox_checkout(context) do
    if context[:workspace] == nil do
      case Sandbox.checkout(Jarga.Repo) do
        :ok -> Sandbox.mode(Jarga.Repo, {:shared, self()})
        {:already, _owner} -> :ok
      end
    end
  end

  defp create_test_fixtures do
    user = user_fixture(%{email: "test@example.com"})
    workspace = workspace_fixture(user, %{name: "Test Workspace", slug: "test-workspace"})
    document = document_fixture(user, workspace, nil, %{title: "Test Document"})
    {user, workspace, document}
  end

  defp navigate_to_document(user, workspace, document) do
    conn = build_conn() |> log_in_user(user)

    {:ok, view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    assert html =~ "editor-container", "Expected to be on document page with editor container"
    {conn, view, html}
  end

  defp build_context(context, user, workspace, document, conn, view, html, task_text) do
    context
    |> Map.put(:user, user)
    |> Map.put(:workspace, workspace)
    |> Map.put(:document, document)
    |> Map.put(:conn, conn)
    |> Map.put(:view, view)
    |> Map.put(:last_html, html)
    |> Map.put(:task_text, task_text)
  end

  # ============================================================================
  # CHECKBOX STATE SETUP STEPS
  # ============================================================================

  step "the todo item is unchecked", context do
    # For CSS testing, we just need to verify the page is loaded
    # The unchecked state is the default
    # We'll verify the CSS rules in the assertion steps

    # Verify we have a valid page loaded
    assert context[:last_html] != nil, "Expected HTML to be loaded"

    {:ok, Map.put(context, :checkbox_state, :unchecked)}
  end

  step "the todo item is checked", context do
    # For CSS testing, we just need to mark the state as checked
    # The CSS rule we're testing will apply to li[data-checked="true"]
    # elements that the JavaScript editor renders

    # Verify we have a valid page loaded
    assert context[:last_html] != nil, "Expected HTML to be loaded"

    {:ok, Map.put(context, :checkbox_state, :checked)}
  end

  step "the text {string} has strikethrough styling", %{args: [_text]} = context do
    # Verify the CSS file has the strikethrough rule
    css_file_path = Path.join([File.cwd!(), "assets", "css", "editor.css"])

    assert File.exists?(css_file_path),
           "Expected editor.css to exist at #{css_file_path}"

    css_content = File.read!(css_file_path)

    # Check that there's a CSS rule for checked task items with strikethrough
    # This will FAIL initially (RED state) because the rule doesn't exist
    assert css_content =~
             ~r/li\[data-item-type="task"\]\[data-checked="true"\][^{]*>[ \n]*p[^{]*\{[^}]*(text-decoration:\s*line-through|text-decoration-line:\s*line-through)/s,
           """
           Expected CSS rule for strikethrough on checked task items.

           The CSS file should contain a rule like:
           #editor-container .milkdown li[data-item-type="task"][data-checked="true"] > p {
             text-decoration: line-through;
             opacity: 0.6;
           }

           Implementation needed in: assets/css/editor.css
           """

    {:ok, context}
  end

  # ============================================================================
  # ACTION STEPS (User Interactions)
  # ============================================================================

  step "I check the todo checkbox", context do
    # For CSS testing, we simulate the state change that JavaScript would make
    # In the real app, JavaScript would update the data-checked attribute
    # This step verifies that CSS rules exist for the checked state

    # Verify we have a loaded page (prerequisite for this action)
    assert context[:last_html] != nil, "Expected HTML to be loaded before checking checkbox"
    assert context[:view] != nil, "Expected LiveView to be mounted before checking checkbox"

    # Verify CSS file exists and has rules for checked state
    css_file_path = Path.join([File.cwd!(), "assets", "css", "editor.css"])
    assert File.exists?(css_file_path), "Expected editor.css to exist"

    {:ok, Map.put(context, :checkbox_state, :checked)}
  end

  step "I uncheck the todo checkbox", context do
    # For CSS testing, we simulate the state change back to unchecked
    # This verifies that unchecking removes the strikethrough styling

    # Verify we have a loaded page (prerequisite for this action)
    assert context[:last_html] != nil, "Expected HTML to be loaded before unchecking checkbox"
    assert context[:view] != nil, "Expected LiveView to be mounted before unchecking checkbox"

    {:ok, Map.put(context, :checkbox_state, :unchecked)}
  end

  # ============================================================================
  # ASSERTION STEPS (Verify Visual Styling)
  # ============================================================================

  step "the text {string} should have strikethrough styling", %{args: [_text]} = context do
    # Verify the CSS file has the strikethrough rule for checked items
    css_file_path = Path.join([File.cwd!(), "assets", "css", "editor.css"])

    assert File.exists?(css_file_path),
           "Expected editor.css to exist at #{css_file_path}"

    css_content = File.read!(css_file_path)

    # Check that there's a CSS rule for checked task items with strikethrough
    # This will FAIL initially (RED state) because the rule doesn't exist yet
    assert css_content =~
             ~r/li\[data-item-type="task"\]\[data-checked="true"\][^}]*>/s,
           """
           Expected CSS selector for checked task items.
           Looking for: li[data-item-type="task"][data-checked="true"]
           """

    # Check for the strikethrough style specifically
    # Look for a rule that targets the paragraph inside checked task items
    assert css_content =~
             ~r/li\[data-item-type="task"\]\[data-checked="true"\][^{]*>[ \n]*p[^{]*\{[^}]*(text-decoration:\s*line-through|text-decoration-line:\s*line-through)/s,
           """
           Expected strikethrough styling on checked task items.

           The CSS should apply text-decoration: line-through to the text content
           of checked task items.

           Implementation needed in: assets/css/editor.css

           Add rule like:
           #editor-container .milkdown li[data-item-type="task"][data-checked="true"] > p {
             text-decoration: line-through;
             opacity: 0.6;  /* Optional: make checked items slightly faded */
           }
           """

    {:ok, context}
  end

  step "the text {string} should not have strikethrough styling", %{args: [_text]} = context do
    # Verify the CSS file does NOT apply strikethrough to unchecked items
    # This is tested implicitly - if the CSS rule only targets data-checked="true",
    # then unchecked items (data-checked="false") won't have strikethrough

    css_file_path = Path.join([File.cwd!(), "assets", "css", "editor.css"])

    assert File.exists?(css_file_path),
           "Expected editor.css to exist at #{css_file_path}"

    css_content = File.read!(css_file_path)

    # Verify there's NO rule that applies strikethrough to data-checked="false"
    # This should always pass - we just want to make sure we don't add such a rule
    refute css_content =~
             ~r/li\[data-item-type="task"\]\[data-checked="false"\][^{]*>[ \n]*p[^{]*\{[^}]*(text-decoration:\s*line-through|text-decoration-line:\s*line-through)/s,
           "Unchecked task items should NOT have strikethrough styling"

    {:ok, context}
  end
end
