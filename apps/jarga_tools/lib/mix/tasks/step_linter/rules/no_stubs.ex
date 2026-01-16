defmodule Mix.Tasks.StepLinter.Rules.NoStubs do
  @moduledoc """
  Detects stub step definitions that don't perform real actions.

  Step definitions should perform actual actions and verifications, not just
  return context with flags set. Stubs lead to:

  - **False positives**: Tests pass without actually testing anything
  - **Silent failures**: Real behavior is never verified
  - **Misleading coverage**: Feature files appear to test functionality that isn't exercised

  ## What is a Stub?

  A stub is a step that only:
  - Returns `{:ok, context}` without doing anything
  - Sets flags in context without performing actions (e.g., `Map.put(context, :clicked, true)`)
  - Has no assertions, LiveView interactions, or database operations

  ## Examples

  ### Bad (stubs):

  ```elixir
  # Only returns context - does nothing
  step "I click the delete button", context do
    {:ok, context}
  end

  # Only sets a flag - no real action
  step "I hover over the message", context do
    {:ok, Map.put(context, :hovered, true)}
  end

  # Inline stub with do:
  step("I confirm deletion", context, do: {:ok, context})
  ```

  ### Good (real implementations):

  ```elixir
  # Performs actual LiveView interaction
  step "I click the delete button", context do
    {view, context} = ensure_view(context)
    html = view |> element("[phx-click=delete]") |> render_click()
    {:ok, Map.put(context, :last_html, html)}
  end

  # Makes assertions
  step "the message should be deleted", context do
    session = context[:chat_session]
    assert session, "Expected session in context"
    {:ok, loaded} = Jarga.Chat.load_session(session.id)
    assert Enum.empty?(loaded.messages)
    {:ok, context}
  end

  # Performs database operations
  step "I have a saved message", context do
    session = chat_session_fixture(%{user: context[:current_user]})
    message = chat_message_fixture(%{chat_session: session})
    {:ok, Map.put(context, :message, message)}
  end
  ```

  ## Detection

  This rule flags steps that:
  1. Have a body that only contains `{:ok, context}` or `{:ok, Map.put(...)}`
  2. Don't call any action functions (render, element, live, assert, etc.)
  3. Don't call any fixture or database functions

  ## Exceptions

  Some legitimate simple steps are allowed:
  - Steps that pattern match and extract args (setup steps)
  - Steps that call helper functions with meaningful names
  - Steps marked with `# stub:ok` comment (explicit acknowledgment)
  """
  use Boundary, top_level?: true

  @behaviour Mix.Tasks.StepLinter.Rule

  # Functions that indicate real work is being done
  @action_functions [
    # LiveView test functions
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
    # Assertions
    :assert,
    :refute,
    :assert_raise,
    :assert_receive,
    :assert_received,
    :refute_receive,
    :refute_received,
    :flunk,
    # Database/Repo operations
    :insert,
    :insert!,
    :update,
    :update!,
    :delete,
    :delete!,
    :get,
    :get!,
    :get_by,
    :get_by!,
    :one,
    :one!,
    :all,
    :preload,
    # Common fixture suffixes (matched by pattern)
    :fixture,
    # Helper functions that do real work
    :ensure_view,
    :send_chat_message,
    :wait_until,
    :broadcast,
    :subscribe,
    # Process/message operations
    :send,
    :receive
  ]

  # Patterns in function names that indicate real work
  # Note: These are compiled at runtime to avoid serialization issues
  defp action_patterns do
    [
      ~r/_fixture$/,
      ~r/^create_/,
      ~r/^update_/,
      ~r/^delete_/,
      ~r/^get_/,
      ~r/^fetch_/,
      ~r/^load_/,
      ~r/^save_/,
      ~r/^verify_/,
      ~r/^validate_/,
      ~r/^check_/,
      ~r/^ensure_/,
      ~r/^assert_/,
      ~r/^refute_/
    ]
  end

  @impl true
  def name, do: "no_stubs"

  @impl true
  def description do
    "Step definitions should perform real actions, not just return context with flags"
  end

  @impl true
  def check(%{body_ast: nil}), do: []

  def check(%{body_ast: body_ast, pattern: pattern, line: step_line}) do
    if stub?(body_ast) do
      [
        %{
          rule: name(),
          message:
            "Step \"#{truncate(pattern, 50)}\" appears to be a stub. " <>
              "It only returns context without performing any real actions or assertions. " <>
              "Consider implementing actual LiveView interactions, assertions, or database operations.",
          severity: :warning,
          line: step_line,
          details: %{
            pattern: pattern,
            suggestion: "Add real implementation or remove if not needed"
          }
        }
      ]
    else
      []
    end
  end

  # Check if the body is a stub
  defp stub?(body_ast) do
    # A stub is a body that:
    # 1. Is just {:ok, context} or {:ok, Map.put(context, ...)}
    # 2. Contains no action function calls
    simple_return?(body_ast) && !has_action_calls?(body_ast)
  end

  # Check if the body is a simple return statement
  defp simple_return?({:ok, {:context, _, _}}), do: true

  defp simple_return?({:ok, {var, _, nil}}) when is_atom(var) do
    var in [:context, :ctx, :state]
  end

  defp simple_return?(
         {:ok, {{:., _, [{:__aliases__, _, [:Map]}, :put]}, _, [{:context, _, _} | _]}}
       ),
       do: true

  defp simple_return?(
         {:ok, {:|>, _, [{:context, _, _}, {{:., _, [{:__aliases__, _, [:Map]}, :put]}, _, _}]}}
       ),
       do: true

  defp simple_return?(
         {:ok, {{:., _, [{:__aliases__, _, [:Map]}, :merge]}, _, [{:context, _, _} | _]}}
       ),
       do: true

  defp simple_return?({:__block__, _, statements}) do
    case List.last(statements) do
      {:ok, _} = return -> simple_return?(return)
      _ -> false
    end
  end

  defp simple_return?(do: inner), do: simple_return?(inner)

  defp simple_return?(_), do: false

  # Check if the AST contains any action function calls
  defp has_action_calls?(ast) do
    {_ast, found} =
      Macro.prewalk(ast, false, fn
        # Direct function call: func(args)
        {func_name, _, args} = node, acc when is_atom(func_name) and is_list(args) ->
          if action_function?(func_name) do
            {node, true}
          else
            {node, acc}
          end

        # Module function call: Module.func(args)
        {{:., _, [_module, func_name]}, _, args} = node, acc
        when is_atom(func_name) and is_list(args) ->
          if action_function?(func_name) do
            {node, true}
          else
            {node, acc}
          end

        # Pipe to function: value |> func(args)
        {:|>, _, [_, {func_name, _, _}]} = node, acc when is_atom(func_name) ->
          if action_function?(func_name) do
            {node, true}
          else
            {node, acc}
          end

        # Pipe to module function: value |> Module.func(args)
        {:|>, _, [_, {{:., _, [_module, func_name]}, _, _}]} = node, acc
        when is_atom(func_name) ->
          if action_function?(func_name) do
            {node, true}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    found
  end

  # Check if a function name indicates real work
  defp action_function?(func_name) when is_atom(func_name) do
    func_name in @action_functions ||
      Enum.any?(action_patterns(), &Regex.match?(&1, Atom.to_string(func_name)))
  end

  defp action_function?(_), do: false

  defp truncate(string, max_length) when byte_size(string) <= max_length, do: string

  defp truncate(string, max_length) do
    String.slice(string, 0, max_length - 3) <> "..."
  end
end
