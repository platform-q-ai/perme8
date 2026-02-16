defmodule Jarga.Test.StepHelpers do
  @moduledoc """
  Shared helper functions for BDD step definitions.

  These helpers provide common utilities for testing including:
  - Retry mechanisms for async operations
  - View navigation helpers
  - Context extraction helpers
  - Assertion helpers

  Usage:
    import Jarga.Test.StepHelpers
    
  Note: ensure_view/1 is a macro because it needs to call Phoenix.LiveViewTest.live/2
  which is itself a macro.
  """

  # Test support module - top-level boundary for BDD step helpers
  use Boundary,
    top_level?: true,
    deps: [
      Agents,
      Agents.AgentsFixtures,
      Jarga.Chat,
      Jarga.ChatFixtures,
      Jarga.WorkspacesFixtures
    ],
    exports: []

  # Required for using Phoenix.LiveViewTest macros
  require Phoenix.LiveViewTest

  # Alias for Phoenix sandbox metadata
  alias Phoenix.Ecto.SQL.Sandbox, as: PhoenixSandbox

  # ============================================================================
  # API CONNECTION HELPERS
  # ============================================================================

  @doc """
  Builds a connection with sandbox metadata header for API tests.

  This is critical for API tests using Phoenix.ConnTest - without the sandbox
  metadata header, the API endpoint runs in a different DB connection and
  can't see data created in the test process.

  ## Example

      conn = build_conn_with_sandbox()
      conn = put_req_header(conn, "authorization", "Bearer \#{token}")
      conn = post(conn, "/api/endpoint", body)

  """
  def build_conn_with_sandbox do
    # Get sandbox metadata for the test process
    metadata = PhoenixSandbox.metadata_for(Jarga.Repo, self())
    encoded_metadata = PhoenixSandbox.encode_metadata(metadata)

    Phoenix.ConnTest.build_conn()
    |> Plug.Conn.put_req_header("user-agent", encoded_metadata)
  end

  # ============================================================================
  # CONTEXT EXTRACTION HELPERS
  # ============================================================================

  @doc """
  Extracts the current user from context.
  Raises if user is not present.

  ## Example

      user = get_user!(context)

  """
  def get_user!(context) do
    context[:current_user] ||
      raise "No user in context. Did you run 'Given I am logged in as a user' step?"
  end

  @doc """
  Extracts the workspace from context, checking multiple keys.
  Returns nil if no workspace found.

  ## Example

      workspace = get_workspace(context)

  """
  def get_workspace(context) do
    context[:workspace] || context[:current_workspace]
  end

  @doc """
  Extracts the workspace from context, raising if not found.

  ## Example

      workspace = get_workspace!(context)

  """
  def get_workspace!(context) do
    get_workspace(context) ||
      raise "No workspace in context. Did you set up a workspace in your scenario?"
  end

  @doc """
  Extracts agents map from context, defaulting to empty map.
  Handles cases where :agents might be set to non-map values.

  ## Example

      agents = get_agents(context)
      updated_agents = Map.put(agents, "New Agent", agent)

  """
  def get_agents(context) do
    case context[:agents] do
      nil -> %{}
      agents when is_map(agents) -> agents
      _ -> %{}
    end
  end

  @doc """
  Gets a specific agent by name from context.

  ## Example

      agent = get_agent(context, "Helper Bot")

  """
  def get_agent(context, agent_name) do
    get_agents(context)[agent_name]
  end

  @doc """
  Extracts the selected agent from context.

  ## Example

      agent = get_selected_agent(context)

  """
  def get_selected_agent(context) do
    context[:selected_agent] || context[:agent]
  end

  @doc """
  Gets or creates a workspace for the current user.
  Returns {workspace, updated_context}.

  ## Example

      {workspace, context} = ensure_workspace(context)

  """
  def ensure_workspace(context, attrs \\ %{}) do
    case get_workspace(context) do
      nil ->
        user = get_user!(context)

        default_attrs = %{
          name: "Test Workspace",
          slug: "test-workspace-#{System.unique_integer([:positive])}"
        }

        workspace =
          Jarga.WorkspacesFixtures.workspace_fixture(user, Map.merge(default_attrs, attrs))

        context =
          context
          |> Map.put(:workspace, workspace)
          |> Map.put(:current_workspace, workspace)

        {workspace, context}

      workspace ->
        {workspace, context}
    end
  end

  @doc """
  Gets or creates an enabled agent for the current user in the workspace.
  Returns {agent, updated_context}.

  ## Example

      {agent, context} = ensure_agent(context, "Test Agent")

  """
  def ensure_agent(context, agent_name, attrs \\ %{}) do
    case get_agent(context, agent_name) do
      nil ->
        user = get_user!(context)
        {workspace, context} = ensure_workspace(context)

        default_attrs = %{name: agent_name, enabled: true}
        agent = Jarga.AgentsFixtures.agent_fixture(user, Map.merge(default_attrs, attrs))
        :ok = Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

        agents = get_agents(context)
        context = Map.put(context, :agents, Map.put(agents, agent_name, agent))

        {agent, context}

      agent ->
        {agent, context}
    end
  end

  @doc """
  Sets up a complete test context with user, workspace, and agent.
  Returns updated context.

  ## Example

      context = setup_chat_context(context, agent_name: "Helper Bot")

  """
  def setup_chat_context(context, opts \\ []) do
    agent_name = Keyword.get(opts, :agent_name, "Test Agent")

    {_workspace, context} = ensure_workspace(context)
    {_agent, context} = ensure_agent(context, agent_name)

    context
  end

  @doc """
  Retries a condition function until it returns true or timeout is reached.
  Use this instead of Process.sleep() for more reliable async testing.

  ## Options
  - `:timeout` - Maximum time to wait in milliseconds (default: 2000)
  - `:interval` - Time between retries in milliseconds (default: 100)

  ## Examples

      # Wait for HTML to contain expected text
      wait_until(fn ->
        html = render(view)
        html =~ "expected text"
      end, timeout: 2000, interval: 100)

      # Returns true if condition was met, false if timeout
      if wait_until(fn -> some_condition() end) do
        # condition was met
      else
        # timed out
      end

  """
  def wait_until(condition_fn, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 2000)
    interval = Keyword.get(opts, :interval, 100)
    start_time = System.monotonic_time(:millisecond)

    do_wait_until(condition_fn, timeout, interval, start_time)
  end

  defp do_wait_until(condition_fn, timeout, interval, start_time) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed > timeout do
      # Timeout reached - return false
      false
    else
      if condition_fn.() do
        true
      else
        Process.sleep(interval)
        do_wait_until(condition_fn, timeout, interval, start_time)
      end
    end
  end

  @doc """
  Ensures a LiveView is available in the context, navigating to dashboard if needed.

  Returns `{view, updated_context}` tuple.

  This is a macro because it needs to call Phoenix.LiveViewTest.live/2 which is itself a macro.

  ## Example

      {view, context} = ensure_view(context)
      html = render(view)

  """
  defmacro ensure_view(context, path \\ "/app/") do
    quote do
      case unquote(context)[:view] do
        nil ->
          conn = unquote(context)[:conn]
          {:ok, view, html} = Phoenix.LiveViewTest.live(conn, unquote(path))

          context =
            unquote(context)
            |> Map.put(:view, view)
            |> Map.put(:last_html, html)

          {view, context}

        view ->
          {view, unquote(context)}
      end
    end
  end

  @doc """
  Waits for a view to contain specific text, with retry logic.

  Returns `{found?, html}` tuple where `found?` is boolean and `html` is the latest rendered HTML.

  ## Example

      {found, html} = wait_for_text_in_view(view, "Welcome")
      assert found, "Expected to find 'Welcome' in view"

  """
  def wait_for_text_in_view(view, expected_text, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 2000)
    interval = Keyword.get(opts, :interval, 100)

    found =
      wait_until(
        fn ->
          html = Phoenix.LiveViewTest.render(view)
          html =~ expected_text
        end,
        timeout: timeout,
        interval: interval
      )

    html = Phoenix.LiveViewTest.render(view)
    {found, html}
  end

  @doc """
  Waits for an element to be present in the view.

  Returns `true` if element was found, `false` if timeout reached.

  ## Example

      found = wait_for_element(view, "#chat-panel-content .chat-bubble")
      assert found, "Expected chat bubble to appear"

  """
  def wait_for_element(view, selector, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 2000)
    interval = Keyword.get(opts, :interval, 100)

    wait_until(
      fn ->
        html = Phoenix.LiveViewTest.render(view)
        html =~ selector or check_has_element?(view, selector)
      end,
      timeout: timeout,
      interval: interval
    )
  end

  # Check if view has an element (handles exceptions gracefully)
  defp check_has_element?(view, selector) do
    Phoenix.LiveViewTest.has_element?(view, selector)
  rescue
    _ -> false
  end

  # ============================================================================
  # CHAT PANEL HELPERS
  # ============================================================================

  @doc """
  Returns the CSS selector for the chat panel content.
  Use this instead of hardcoding the selector everywhere.

  ## Example

      html = view |> element(chat_panel_target() <> " .chat-bubble") |> render()

  """
  def chat_panel_target, do: "#chat-panel-content"

  @doc """
  Returns the CSS selector for the chat messages container.
  """
  def chat_messages_target, do: "#chat-messages"

  @doc """
  Returns the CSS selector for the chat input form.
  """
  def chat_form_target, do: "#chat-message-form"

  # ============================================================================
  # ASSERTION HELPERS
  # ============================================================================

  @doc """
  Asserts that HTML contains expected content with a descriptive error message.

  ## Example

      assert_html_contains(html, "Welcome", "chat panel")

  """
  def assert_html_contains(html, expected, location \\ "HTML") do
    unless html =~ expected do
      snippet = String.slice(html, 0, 500)

      raise ExUnit.AssertionError,
        message: """
        Expected to find "#{expected}" in #{location}.

        HTML snippet (first 500 chars):
        #{snippet}
        """
    end

    true
  end

  @doc """
  Refutes that HTML contains unexpected content with a descriptive error message.

  ## Example

      refute_html_contains(html, "Error", "success page")

  """
  def refute_html_contains(html, unexpected, location \\ "HTML") do
    if html =~ unexpected do
      raise ExUnit.AssertionError,
        message: """
        Expected NOT to find "#{unexpected}" in #{location}, but it was present.
        """
    end

    true
  end

  @doc """
  Waits for streaming to complete (loading indicators to disappear).

  ## Example

      wait_for_streaming_complete(view)

  """
  def wait_for_streaming_complete(view, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)

    wait_until(
      fn ->
        html = Phoenix.LiveViewTest.render(view)

        not String.contains?(html, "loading-dots") and
          not String.contains?(html, "loading-spinner") and
          not String.contains?(html, "Thinking...")
      end,
      timeout: timeout,
      interval: 100
    )
  end

  # ============================================================================
  # MESSAGE SENDING HELPERS
  # ============================================================================

  @doc """
  Sends a message via the chat panel form.

  Takes a view and message, performs the textarea change and form submit.
  Returns the resulting HTML.

  ## Example

      html = send_chat_message(view, "Hello agent")

  """
  def send_chat_message(view, message) do
    # Update input via textarea change
    view
    |> Phoenix.LiveViewTest.element(chat_panel_target() <> " textarea[name=message]")
    |> Phoenix.LiveViewTest.render_change(%{"message" => message})

    # Submit the form
    view
    |> Phoenix.LiveViewTest.element(chat_panel_target() <> " form#chat-message-form")
    |> Phoenix.LiveViewTest.render_submit(%{"message" => message})
  end

  # ============================================================================
  # DATABASE VERIFICATION HELPERS
  # ============================================================================

  @doc """
  Counts total messages across a user's recent sessions.

  Returns the total count of messages found.

  ## Example

      count = count_user_messages(user.id, limit: 5)

  """
  def count_user_messages(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    case Jarga.Chat.list_sessions(user_id, limit: limit) do
      {:ok, sessions} -> Enum.reduce(sessions, 0, &count_session_messages/2)
      _ -> 0
    end
  end

  defp count_session_messages(session, acc) do
    case Jarga.Chat.load_session(session.id) do
      {:ok, loaded} -> acc + length(loaded.messages)
      _ -> acc
    end
  end

  @doc """
  Checks if any session has messages with a specific role.

  Returns boolean indicating if any messages with the role were found.

  ## Example

      has_assistant = has_messages_with_role?(user.id, "assistant")

  """
  def has_messages_with_role?(user_id, role, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    case Jarga.Chat.list_sessions(user_id, limit: limit) do
      {:ok, sessions} -> Enum.any?(sessions, &session_has_role?(&1, role))
      _ -> false
    end
  end

  defp session_has_role?(session, role) do
    case Jarga.Chat.load_session(session.id) do
      {:ok, loaded} -> Enum.any?(loaded.messages, fn msg -> msg.role == role end)
      _ -> false
    end
  end

  @doc """
  Finds a specific message by content in user's sessions and returns its role.

  Returns the role string if found, nil otherwise.

  ## Example

      role = find_message_role(user.id, "Hello world")

  """
  def find_message_role(user_id, message_content, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    case Jarga.Chat.list_sessions(user_id, limit: limit) do
      {:ok, sessions} ->
        Enum.find_value(sessions, &find_message_role_in_session(&1, message_content))

      _ ->
        nil
    end
  end

  defp find_message_role_in_session(session, message_content) do
    case Jarga.Chat.load_session(session.id) do
      {:ok, loaded} -> find_role_by_content(loaded.messages, message_content)
      _ -> nil
    end
  end

  defp find_role_by_content(messages, message_content) do
    Enum.find_value(messages, fn msg ->
      if msg.content == message_content, do: msg.role
    end)
  end

  @doc """
  Checks if a specific message content exists in user's sessions with a given role.

  Returns boolean indicating if the message was found with the expected role.

  ## Example

      found = message_exists_with_role?(user.id, "Hello", "user")

  """
  def message_exists_with_role?(user_id, message_content, role, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    case Jarga.Chat.list_sessions(user_id, limit: limit) do
      {:ok, sessions} ->
        Enum.any?(sessions, &message_exists_in_session?(&1, message_content, role))

      _ ->
        false
    end
  end

  defp message_exists_in_session?(session, message_content, role) do
    case Jarga.Chat.load_session(session.id) do
      {:ok, loaded} ->
        Enum.any?(loaded.messages, fn msg ->
          msg.content == message_content && msg.role == role
        end)

      _ ->
        false
    end
  end

  @doc """
  Verifies that messages are ordered by timestamp (ascending) within sessions.

  Returns `:ok` if all messages are ordered correctly, raises if not.

  ## Example

      :ok = verify_message_ordering!(user.id)

  """
  def verify_message_ordering!(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    with {:ok, sessions} <- Jarga.Chat.list_sessions(user_id, limit: limit) do
      Enum.each(sessions, &verify_session_message_ordering!/1)
    end

    :ok
  end

  defp verify_session_message_ordering!(session) do
    with {:ok, loaded} <- Jarga.Chat.load_session(session.id) do
      timestamps = Enum.map(loaded.messages, fn msg -> msg.inserted_at end)
      sorted_timestamps = Enum.sort(timestamps, DateTime)

      unless timestamps == sorted_timestamps do
        raise ExUnit.AssertionError,
          message: "Expected messages to be ordered by timestamp"
      end
    end
  end

  # ============================================================================
  # PROJECT HELPERS
  # ============================================================================

  @doc """
  Finds the most recently created project with the given name,
  excluding any existing project that was in context before creation.

  Returns the project or nil if not found.

  ## Example

      projects = Projects.list_projects_for_workspace(user, workspace.id)
      project = find_newly_created_project(projects, "My Project", existing_id)

  """
  def find_newly_created_project(projects, name, existing_project_id) do
    projects
    |> Enum.filter(fn p -> p.name == name end)
    |> Enum.reject(fn p -> existing_project_id && p.id == existing_project_id end)
    |> select_project_from_matches(projects, name)
  end

  defp select_project_from_matches([], projects, name) do
    # Fallback: get any project with matching name
    Enum.find(projects, fn p -> p.name == name end)
  end

  defp select_project_from_matches([single], _projects, _name), do: single

  defp select_project_from_matches(multiple, _projects, _name) do
    # Multiple matches: get the most recent one
    multiple
    |> Enum.sort_by(
      fn p -> {p.inserted_at, p.id} end,
      &compare_projects_by_date/2
    )
    |> List.first()
  end

  defp compare_projects_by_date({t1, id1}, {t2, id2}) do
    case DateTime.compare(t1, t2) do
      :gt -> true
      :lt -> false
      :eq -> id1 > id2
    end
  end

  # ============================================================================
  # CHAT MESSAGE HELPERS
  # ============================================================================

  @doc """
  Creates a chat message fixture and updates the panel via send_update.
  Returns {session, message}.

  ## Example

      {session, message} = create_and_display_message(
        view, user, workspace, session, "assistant", "Hello!"
      )

  """
  def create_and_display_message(view, user, workspace, session, role, content) do
    session =
      session || Jarga.ChatFixtures.chat_session_fixture(%{user: user, workspace: workspace})

    message =
      Jarga.ChatFixtures.chat_message_fixture(%{
        chat_session: session,
        role: role,
        content: content
      })

    Phoenix.LiveView.send_update(view.pid, JargaWeb.ChatLive.Panel,
      id: "global-chat-panel",
      messages: [
        %{
          id: message.id,
          role: role,
          content: content,
          timestamp: DateTime.utc_now(),
          source: nil
        }
      ],
      current_session_id: session.id,
      from_pubsub: true
    )

    {session, message}
  end
end
