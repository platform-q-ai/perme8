defmodule Mix.Tasks.StepLinter.Rules.UseLiveviewTesting do
  @moduledoc """
  Enforces that BDD step definitions use LiveView testing instead of direct backend calls.

  BDD tests should verify the full stack (HTTP → HTML), not just backend logic.
  Steps should interact with the UI through LiveView test helpers, not call
  context functions directly.

  ## Why This Matters

  - **Full-stack verification**: Tests should verify the entire user journey
  - **UI regression detection**: Catches broken buttons, forms, and interactions
  - **Executable documentation**: Tests demonstrate how users actually use the system
  - **Backend tests exist**: Unit tests already cover backend logic in isolation

  ## What to Avoid

  Direct calls to context/business logic functions in BDD steps:

  ### Bad (backend-only testing):

  ```elixir
  step "I create a workspace", context do
    user = context[:current_user]
    result = Jarga.Workspaces.create_workspace(user.id, %{name: "My Workspace"})
    {:ok, Map.put(context, :workspace, result)}
  end

  step "I add a document", context do
    workspace = context[:workspace]
    doc = Jarga.Documents.create_document(workspace.id, %{title: "Doc"})
    {:ok, Map.put(context, :document, doc)}
  end
  ```

  ### Good (LiveView testing):

  ```elixir
  step "I create a workspace", context do
    {view, context} = ensure_view(context)
    
    view
    |> element("button[phx-click=new_workspace]")
    |> render_click()
    
    view
    |> form("#workspace-form", workspace: %{name: "My Workspace"})
    |> render_submit()
    
    {:ok, Map.put(context, :view, view)}
  end

  step "I add a document", context do
    {view, context} = ensure_view(context)
    
    view
    |> element("button[phx-click=new_document]")
    |> render_click()
    
    html =
      view
      |> form("#document-form", document: %{title: "Doc"})
      |> render_submit()
    
    {:ok, Map.put(context, :last_html, html)}
  end
  ```

  ## Exceptions

  Some steps legitimately need backend calls:

  1. **Setup steps** (Given) - Creating test data that doesn't have UI
     ```elixir
     # Allowed: Setting up test data
     step "the following users exist:", context do
       users = create_users_from_table(context.datatable)
       {:ok, Map.put(context, :users, users)}
     end
     ```

  2. **Background data** - Pre-existing state before user interaction
     ```elixir
     # Allowed: Background data setup
     step "workspace {string} has a project {string}", %{args: [ws, proj]} = context do
       workspace = get_workspace_by_slug(ws)
       project = create_project(workspace, %{name: proj})
       {:ok, Map.put(context, :project, project)}
     end
     ```

  3. **Verification steps** (Then) - Checking backend state after UI interaction
     ```elixir
     # Allowed: Verifying backend state changed
     step "the document should be saved in the database", context do
       doc_id = context[:document_id]
       doc = Jarga.Documents.get_document(doc_id)
       assert doc
       assert doc.title == "My Document"
       {:ok, context}
     end
     ```

  ## Detection

  This rule flags "When" and "Then" steps that:
  1. Call context module functions (e.g., `Jarga.Workspaces.*`, `Jarga.Documents.*`)
  2. Don't use LiveView test functions (`render_click`, `element`, `live`, etc.)
  3. Aren't marked as background/setup steps

  "Given" steps are more lenient as they often set up test data.
  """

  @behaviour Mix.Tasks.StepLinter.Rule

  # LiveView test functions that indicate UI testing
  @liveview_functions [
    :render,
    :render_click,
    :render_submit,
    :render_change,
    :render_keydown,
    :render_keyup,
    :render_blur,
    :render_focus,
    :render_hook,
    :element,
    :form,
    :live,
    :live_redirect,
    :follow_redirect,
    :push_navigate,
    :push_patch,
    :ensure_view,
    :has_element?,
    :page_title
  ]

  # Context modules that should not be called directly in action steps
  @context_modules [
    :Accounts,
    :Workspaces,
    :Documents,
    :Projects,
    :Chat,
    :Agents,
    :Notifications
  ]

  # Patterns in step text that indicate setup/background steps (more lenient)
  defp setup_step_patterns do
    [
      ~r/^(the following|a|an)\s+\w+\s+(exist|has|have|is|are)/i,
      ~r/^workspace\s+.*\s+has/i,
      ~r/^project\s+.*\s+has/i,
      ~r/^user\s+.*\s+has/i,
      ~r/^agent\s+.*\s+has/i,
      ~r/is a member of/i,
      ~r/is logged in as/i,
      ~r/^I have\s+(a|an|the)/i,
      ~r/^I had\s+(a|an|the)/i,
      ~r/^\{string\}\s+has/i,
      ~r/^.*\s+is\s+(deleted|updated|created)\s+(by|from)/i,
      ~r/^.*\s+(was|were)\s+created/i
    ]
  end

  # Patterns that indicate action steps (should use LiveView)
  defp action_step_patterns do
    [
      ~r/^I\s+(click|press|tap|select|choose|open|close|toggle)/i,
      ~r/^I\s+submit\s+/i,
      ~r/^I\s+(create|add|delete|remove)\s+(a|an|the)\s+/i,
      ~r/^I\s+(update|edit|change|modify)\s+(a|an|the)\s+/i,
      ~r/^I\s+(navigate|go|visit|view|access)/i,
      ~r/^I\s+(fill|enter|type|input|upload)/i,
      ~r/^I\s+make\s+a\s+(GET|POST|PUT|PATCH|DELETE)\s+request/i
    ]
  end

  @impl true
  def name, do: "use_liveview_testing"

  @impl true
  def description do
    "BDD steps should use LiveView testing instead of calling backend functions directly"
  end

  @impl true
  def check(%{body_ast: nil}), do: []

  def check(%{body_ast: body_ast, pattern: pattern, line: step_line}) do
    cond do
      # Skip setup/background steps
      setup_step?(pattern) ->
        []

      # Skip verification steps (have assertions)
      verification_step?(pattern) && has_assertions?(body_ast) ->
        []

      # Flag action steps that use backend calls without LiveView
      action_step?(pattern) && uses_backend_directly?(body_ast) &&
          !uses_liveview_testing?(body_ast) ->
        [
          %{
            rule: name(),
            message:
              "Step \"#{truncate(pattern, 60)}\" calls backend functions directly. " <>
                "BDD tests should use LiveView testing to verify the full stack (HTTP → HTML). " <>
                "Use render_click(), element(), form(), etc. instead of calling context functions.",
            severity: :warning,
            line: step_line,
            details: %{
              pattern: pattern,
              suggestion:
                "Replace direct backend calls with LiveView interactions (e.g., render_click, element, form)"
            }
          }
        ]

      # Skip steps that have assertions (likely verification steps)
      has_assertions?(body_ast) ->
        []

      true ->
        []
    end
  end

  # Check if step pattern indicates setup/background
  defp setup_step?(pattern) do
    Enum.any?(setup_step_patterns(), &Regex.match?(&1, pattern))
  end

  # Check if step pattern indicates user action
  defp action_step?(pattern) do
    Enum.any?(action_step_patterns(), &Regex.match?(&1, pattern))
  end

  # Check if step pattern indicates verification (Then steps)
  defp verification_step?(pattern) do
    pattern =~ ~r/^(the|it|they)\s+/i or
      pattern =~ ~r/\s+should\s+/i or
      pattern =~ ~r/^.*\s+(should be|should have|should not)/i
  end

  # Check if AST calls backend context modules directly
  defp uses_backend_directly?(ast) do
    {_ast, found} =
      Macro.prewalk(ast, false, fn
        # Module function call: Jarga.Module.function(...)
        {{:., _, [{:__aliases__, _, [:Jarga | module_path]}, _func]}, _, _args} = node, _acc ->
          # Check if it's a context module
          context_module? = Enum.any?(@context_modules, fn mod -> mod in module_path end)
          {node, context_module?}

        # Aliased module call: Module.function(...)
        {{:., _, [{:__aliases__, _, module_path}, _func]}, _, _args} = node, acc ->
          # Check if it's a context module
          context_module? = Enum.any?(@context_modules, fn mod -> mod in module_path end)
          {node, acc || context_module?}

        node, acc ->
          {node, acc}
      end)

    found
  end

  # Check if AST uses LiveView testing functions
  defp uses_liveview_testing?(ast) do
    {_ast, found} =
      Macro.prewalk(ast, false, fn
        # Direct function call: func(args)
        {func_name, _, args} = node, acc when is_atom(func_name) and is_list(args) ->
          if func_name in @liveview_functions do
            {node, true}
          else
            {node, acc}
          end

        # Pipe to function: value |> func(args)
        {:|>, _, [_, {func_name, _, _}]} = node, acc when is_atom(func_name) ->
          if func_name in @liveview_functions do
            {node, true}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    found
  end

  # Check if AST has assertions (indicates verification step)
  defp has_assertions?(ast) do
    {_ast, found} =
      Macro.prewalk(ast, false, fn
        {func_name, _, args} = node, acc when is_atom(func_name) and is_list(args) ->
          if func_name in [:assert, :refute, :assert_raise, :assert_receive, :refute_receive] do
            {node, true}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    found
  end

  defp truncate(string, max_length) when byte_size(string) <= max_length, do: string

  defp truncate(string, max_length) do
    String.slice(string, 0, max_length - 3) <> "..."
  end
end
