defmodule Chat.Test.StepHelpers do
  @moduledoc """
  Shared helper functions for chat BDD step definitions.
  """

  use Boundary,
    top_level?: true,
    deps: [
      Agents,
      Agents.AgentsFixtures,
      Chat,
      Chat.ChatFixtures,
      Identity,
      Identity.AccountsFixtures,
      Identity.WorkspacesFixtures
    ],
    exports: []

  require Phoenix.LiveViewTest

  import Identity.WorkspacesFixtures

  def get_user!(context) do
    context[:current_user] ||
      raise "No user in context. Did you run 'Given I am logged in as a user' step?"
  end

  def get_workspace(context) do
    context[:workspace] || context[:current_workspace]
  end

  def get_workspace!(context) do
    get_workspace(context) ||
      raise "No workspace in context. Did you set up a workspace in your scenario?"
  end

  def get_agents(context) do
    case context[:agents] do
      nil -> %{}
      agents when is_map(agents) -> agents
      _ -> %{}
    end
  end

  def get_agent(context, agent_name), do: get_agents(context)[agent_name]

  def ensure_workspace(context, attrs \\ %{}) do
    case get_workspace(context) do
      nil ->
        user = get_user!(context)

        default_attrs = %{
          name: "Test Workspace",
          slug: "test-workspace-#{System.unique_integer([:positive])}"
        }

        workspace = workspace_fixture(user, Map.merge(default_attrs, attrs))

        context =
          context
          |> Map.put(:workspace, workspace)
          |> Map.put(:current_workspace, workspace)

        {workspace, context}

      workspace ->
        {workspace, context}
    end
  end

  def ensure_agent(context, agent_name, attrs \\ %{}) do
    case get_agent(context, agent_name) do
      nil ->
        user = get_user!(context)
        {workspace, context} = ensure_workspace(context)

        default_attrs = %{name: agent_name, enabled: true}
        agent = Agents.AgentsFixtures.agent_fixture(user, Map.merge(default_attrs, attrs))
        :ok = Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

        agents = get_agents(context)
        context = Map.put(context, :agents, Map.put(agents, agent_name, agent))

        {agent, context}

      agent ->
        {agent, context}
    end
  end

  def setup_chat_context(context, opts \\ []) do
    agent_name = Keyword.get(opts, :agent_name, "Test Agent")

    {_workspace, context} = ensure_workspace(context)
    {_agent, context} = ensure_agent(context, agent_name)

    context
  end

  def wait_until(condition_fn, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 2000)
    interval = Keyword.get(opts, :interval, 100)
    start_time = System.monotonic_time(:millisecond)

    do_wait_until(condition_fn, timeout, interval, start_time)
  end

  defp do_wait_until(condition_fn, timeout, interval, start_time) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed > timeout do
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

  defp check_has_element?(view, selector) do
    Phoenix.LiveViewTest.has_element?(view, selector)
  rescue
    _ -> false
  end

  def chat_panel_target, do: "#chat-panel-content"
  def chat_messages_target, do: "#chat-messages"
  def chat_form_target, do: "#chat-message-form"

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

  def send_chat_message(view, message) do
    view
    |> Phoenix.LiveViewTest.element(chat_panel_target() <> " textarea[name=message]")
    |> Phoenix.LiveViewTest.render_change(%{"message" => message})

    view
    |> Phoenix.LiveViewTest.element(chat_panel_target() <> " form#chat-message-form")
    |> Phoenix.LiveViewTest.render_submit(%{"message" => message})
  end

  def count_user_messages(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    case Chat.list_sessions(user_id, limit: limit) do
      {:ok, sessions} -> Enum.reduce(sessions, 0, &count_session_messages/2)
      _ -> 0
    end
  end

  defp count_session_messages(session, acc) do
    case Chat.load_session(session.id) do
      {:ok, loaded} -> acc + length(loaded.messages)
      _ -> acc
    end
  end

  def has_messages_with_role?(user_id, role, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    case Chat.list_sessions(user_id, limit: limit) do
      {:ok, sessions} -> Enum.any?(sessions, &session_has_role?(&1, role))
      _ -> false
    end
  end

  defp session_has_role?(session, role) do
    case Chat.load_session(session.id) do
      {:ok, loaded} -> Enum.any?(loaded.messages, fn msg -> msg.role == role end)
      _ -> false
    end
  end

  def find_message_role(user_id, message_content, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    case Chat.list_sessions(user_id, limit: limit) do
      {:ok, sessions} ->
        Enum.find_value(sessions, &find_message_role_in_session(&1, message_content))

      _ ->
        nil
    end
  end

  defp find_message_role_in_session(session, message_content) do
    case Chat.load_session(session.id) do
      {:ok, loaded} -> find_role_by_content(loaded.messages, message_content)
      _ -> nil
    end
  end

  defp find_role_by_content(messages, message_content) do
    Enum.find_value(messages, fn msg ->
      if msg.content == message_content, do: msg.role
    end)
  end

  def message_exists_with_role?(user_id, message_content, role, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    case Chat.list_sessions(user_id, limit: limit) do
      {:ok, sessions} ->
        Enum.any?(sessions, &message_exists_in_session?(&1, message_content, role))

      _ ->
        false
    end
  end

  defp message_exists_in_session?(session, message_content, role) do
    case Chat.load_session(session.id) do
      {:ok, loaded} ->
        Enum.any?(loaded.messages, fn msg ->
          msg.content == message_content && msg.role == role
        end)

      _ ->
        false
    end
  end

  def verify_message_ordering!(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 5)

    with {:ok, sessions} <- Chat.list_sessions(user_id, limit: limit) do
      Enum.each(sessions, &verify_session_message_ordering!/1)
    end

    :ok
  end

  defp verify_session_message_ordering!(session) do
    with {:ok, loaded} <- Chat.load_session(session.id) do
      timestamps = Enum.map(loaded.messages, fn msg -> msg.inserted_at end)
      sorted_timestamps = Enum.sort(timestamps, DateTime)

      unless timestamps == sorted_timestamps do
        raise ExUnit.AssertionError,
          message: "Expected messages to be ordered by timestamp"
      end
    end
  end

  def create_and_display_message(view, user, workspace, session, role, content) do
    session =
      session || Chat.ChatFixtures.chat_session_fixture(%{user: user, workspace: workspace})

    message =
      Chat.ChatFixtures.chat_message_fixture(%{
        chat_session: session,
        role: role,
        content: content
      })

    Phoenix.LiveView.send_update(view.pid, ChatWeb.ChatLive.Panel,
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
