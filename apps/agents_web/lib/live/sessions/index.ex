defmodule AgentsWeb.SessionsLive.Index do
  @moduledoc """
  LiveView for the session manager — split-panel layout.

  Left panel: list of sessions (grouped by container_id) with
  creation/deletion controls.

  Right panel: active session detail with instruction form,
  real-time output log, and task history for the selected session.
  """

  use AgentsWeb, :live_view

  alias Agents.Sessions

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    sessions = Sessions.list_sessions(user.id)
    tasks = Sessions.list_tasks(user.id)

    if connected?(socket), do: subscribe_to_active_tasks(tasks)

    # Select the most recent session by default
    active_container_id =
      case sessions do
        [first | _] -> first.container_id
        [] -> nil
      end

    current_task = find_current_task(tasks, active_container_id)

    {:ok,
     socket
     |> assign(:page_title, "Sessions")
     |> assign(:full_width, true)
     |> assign(:sessions, sessions)
     |> assign(:tasks, tasks)
     |> assign(:active_container_id, active_container_id)
     |> assign(:current_task, current_task)
     |> assign(:composing_new, false)
     |> assign(:events, [])
     |> assign_session_state()
     |> assign(:form, to_form(%{"instruction" => ""}))
     |> maybe_load_cached_output(current_task)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  # ---- Events ----

  @impl true
  def handle_event("run_task", %{"instruction" => instruction}, socket) do
    instruction = String.trim(instruction)

    if instruction == "" do
      {:noreply, put_flash(socket, :error, "Instruction is required")}
    else
      socket
      |> run_or_resume_task(instruction)
      |> handle_task_result(socket)
    end
  end

  @impl true
  def handle_event("cancel_task", _params, socket) do
    case socket.assigns.current_task do
      nil -> {:noreply, socket}
      task -> do_cancel_task(task, socket)
    end
  end

  @impl true
  def handle_event("new_session", _params, socket) do
    {:noreply,
     socket
     |> assign(:active_container_id, nil)
     |> assign(:current_task, nil)
     |> assign(:composing_new, true)
     |> assign(:events, [])
     |> assign_session_state()
     |> assign(:form, to_form(%{"instruction" => ""}))}
  end

  @impl true
  def handle_event("select_session", %{"container-id" => container_id}, socket) do
    user = socket.assigns.current_scope.user
    tasks = Sessions.list_tasks(user.id)
    current_task = find_current_task(tasks, container_id)

    if current_task && active_task?(current_task) do
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{current_task.id}")
    end

    {:noreply,
     socket
     |> assign(:tasks, tasks)
     |> assign(:active_container_id, container_id)
     |> assign(:current_task, current_task)
     |> assign(:composing_new, false)
     |> assign(:events, [])
     |> assign_session_state()
     |> assign(:form, to_form(%{"instruction" => ""}))
     |> maybe_load_cached_output(current_task)}
  end

  @impl true
  def handle_event("delete_session", %{"container-id" => container_id}, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.delete_session(container_id, user.id) do
      :ok ->
        # If we deleted the active session, clear the right panel
        socket =
          if socket.assigns.active_container_id == container_id do
            socket
            |> assign(:active_container_id, nil)
            |> assign(:current_task, nil)
            |> assign(:events, [])
            |> assign_session_state()
          else
            socket
          end

        {:noreply,
         socket
         |> reload_all(user.id)
         |> put_flash(:info, "Session deleted")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete session")}
    end
  end

  @impl true
  def handle_event("delete_task", %{"task-id" => task_id}, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.delete_task(task_id, user.id) do
      :ok ->
        socket =
          if socket.assigns.current_task && socket.assigns.current_task.id == task_id do
            # Re-select the session to pick the next latest task
            tasks = Sessions.list_tasks(user.id)
            current_task = find_current_task(tasks, socket.assigns.active_container_id)

            socket
            |> assign(:tasks, tasks)
            |> assign(:current_task, current_task)
            |> assign(:events, [])
            |> assign_session_state()
            |> maybe_load_cached_output(current_task)
          else
            reload_all(socket, user.id)
          end

        {:noreply,
         socket
         |> reload_all(user.id)
         |> put_flash(:info, "Task deleted")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete task")}
    end
  end

  @impl true
  def handle_event("view_task", %{"task-id" => task_id}, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.get_task(task_id, user.id) do
      {:ok, task} ->
        if active_task?(task) do
          Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")
        end

        {:noreply,
         socket
         |> assign(:current_task, task)
         |> assign(:events, [])
         |> assign_session_state()
         |> maybe_load_cached_output(task)}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Task not found")}
    end
  end

  # ---- Event helpers ----

  defp run_or_resume_task(socket, instruction) do
    user = socket.assigns.current_scope.user
    current_task = socket.assigns.current_task

    if resumable_task?(current_task) do
      Sessions.resume_task(current_task.id, %{instruction: instruction, user_id: user.id})
    else
      Sessions.create_task(%{instruction: instruction, user_id: user.id})
    end
  end

  defp handle_task_result({:ok, task}, socket) do
    user = socket.assigns.current_scope.user
    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

    # If this was a new session (no active container), set the container_id
    # once the task comes back with one
    active_container_id = task.container_id || socket.assigns.active_container_id

    {:noreply,
     socket
     |> assign(:current_task, task)
     |> assign(:active_container_id, active_container_id)
     |> assign(:composing_new, false)
     |> assign(:events, [])
     |> assign_session_state()
     |> assign(:form, to_form(%{"instruction" => ""}))
     |> reload_all(user.id)}
  end

  defp handle_task_result({:error, reason}, socket) do
    {:noreply, put_flash(socket, :error, task_error_message(reason))}
  end

  defp task_error_message(:instruction_required), do: "Instruction is required"
  defp task_error_message(:not_resumable), do: "This session cannot be resumed"
  defp task_error_message(:no_container), do: "No container available for resume"
  defp task_error_message(:no_session), do: "No session available for resume"
  defp task_error_message(_), do: "Failed to create task"

  defp do_cancel_task(task, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.cancel_task(task.id, user.id) do
      :ok ->
        updated_task =
          case Sessions.get_task(task.id, user.id) do
            {:ok, t} -> t
            _ -> Map.put(task, :status, "cancelled")
          end

        {:noreply,
         socket
         |> assign(:current_task, updated_task)
         |> reload_all(user.id)
         |> put_flash(:info, "Task cancelled")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel task")}
    end
  end

  # ---- PubSub callbacks ----

  @impl true
  def handle_info({:task_event, task_id, event}, socket) do
    # Only render output for the task currently being viewed
    case socket.assigns.current_task do
      %{id: ^task_id} -> {:noreply, process_event(event, socket)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:task_status_changed, task_id, status}, socket) do
    current_task = socket.assigns.current_task
    updated_task = maybe_update_task_status(current_task, task_id, status, socket)

    # When a task gets a container_id (status changes from pending to starting/running),
    # capture the container_id so the session list updates correctly
    active_container_id =
      cond do
        updated_task && updated_task.container_id ->
          updated_task.container_id

        true ->
          socket.assigns.active_container_id
      end

    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:current_task, updated_task)
      |> assign(:active_container_id, active_container_id)
      |> update_task_in_list(task_id, status)
      |> reload_all(user.id)

    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp maybe_update_task_status(nil, _task_id, _status, _socket), do: nil

  defp maybe_update_task_status(%{id: id} = task, task_id, _status, _socket) when id != task_id,
    do: task

  defp maybe_update_task_status(task, task_id, "failed", socket) do
    user = socket.assigns.current_scope.user

    case Sessions.get_task(task_id, user.id) do
      {:ok, %{error: error} = refreshed} when not is_nil(error) -> refreshed
      _ -> Map.put(task, :status, "failed")
    end
  end

  defp maybe_update_task_status(task, task_id, status, socket) do
    # Refresh from DB to get container_id etc., but always trust the
    # PubSub status since it may arrive before the DB write completes.
    user = socket.assigns.current_scope.user

    case Sessions.get_task(task_id, user.id) do
      {:ok, refreshed} -> Map.put(refreshed, :status, status)
      _ -> Map.put(task, :status, status)
    end
  end

  # ---- Session state ----

  defp assign_session_state(socket) do
    socket
    |> assign(:session_title, nil)
    |> assign(:session_model, nil)
    |> assign(:session_tokens, nil)
    |> assign(:session_cost, nil)
    |> assign(:session_summary, nil)
    |> assign(:output_parts, [])
  end

  # ---- Event processing ----

  defp process_event(%{"type" => "session.updated", "properties" => %{"info" => info}}, socket) do
    socket
    |> maybe_assign(:session_title, info["title"])
    |> maybe_assign(:session_summary, info["summary"])
  end

  defp process_event(
         %{
           "type" => "message.updated",
           "properties" => %{"info" => %{"role" => "assistant"} = info}
         },
         socket
       ) do
    socket
    |> maybe_assign(:session_model, format_model(info))
    |> maybe_assign(:session_tokens, info["tokens"])
    |> maybe_assign(:session_cost, info["cost"])
  end

  defp process_event(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "text", "text" => text}}
         },
         socket
       )
       when text != "" do
    part_id = get_in(socket, [Access.key(:assigns), Access.key(:events)]) |> length()
    parts = update_output_part(socket.assigns.output_parts, part_id, text)
    assign(socket, :output_parts, parts)
  end

  defp process_event(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "tool-start"} = part}
         },
         socket
       ) do
    tool_name = part["name"] || "tool"
    parts = socket.assigns.output_parts ++ [{:tool, tool_name, :running}]
    assign(socket, :output_parts, parts)
  end

  defp process_event(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "tool-result"} = part}
         },
         socket
       ) do
    tool_name = part["name"] || "tool"
    parts = socket.assigns.output_parts ++ [{:tool, tool_name, :done}]
    assign(socket, :output_parts, parts)
  end

  defp process_event(_event, socket), do: socket

  defp maybe_assign(socket, _key, nil), do: socket
  defp maybe_assign(socket, key, value), do: assign(socket, key, value)

  defp update_output_part(parts, _id, text) do
    case List.last(parts) do
      {:text, _old} -> List.replace_at(parts, -1, {:text, text})
      _ -> parts ++ [{:text, text}]
    end
  end

  defp format_model(%{"modelID" => model_id}), do: model_id
  defp format_model(_), do: nil

  # ---- Cached output ----

  defp maybe_load_cached_output(socket, %{output: output})
       when is_binary(output) and output != "" do
    assign(socket, :output_parts, [{:text, output}])
  end

  defp maybe_load_cached_output(socket, _task), do: socket

  # ---- Helpers ----

  defp find_current_task(tasks, nil), do: Enum.find(tasks, &active_task?/1)

  defp find_current_task(tasks, container_id) do
    session_tasks =
      tasks
      |> Enum.filter(&(&1.container_id == container_id))

    # Prefer running task, otherwise latest
    Enum.find(session_tasks, &active_task?/1) || List.first(session_tasks)
  end

  defp session_tasks(tasks, container_id) do
    tasks
    |> Enum.filter(&(&1.container_id == container_id))
  end

  defp update_task_in_list(socket, task_id, status) do
    tasks =
      Enum.map(socket.assigns.tasks, fn
        %{id: ^task_id} = task -> Map.put(task, :status, status)
        task -> task
      end)

    assign(socket, :tasks, tasks)
  end

  defp reload_all(socket, user_id) do
    sessions = Sessions.list_sessions(user_id)
    tasks = Sessions.list_tasks(user_id)

    socket
    |> assign(:sessions, sessions)
    |> assign(:tasks, tasks)
  end

  defp render_markdown(text) when is_binary(text) do
    opts = [
      extension: [
        strikethrough: true,
        table: true,
        tasklist: true,
        autolink: true
      ]
    ]

    case MDEx.to_html(text, opts) do
      {:ok, html} -> Phoenix.HTML.raw(html)
      {:error, _} -> text
    end
  end

  defp render_markdown(text), do: text

  defp format_error(error) when is_binary(error), do: error
  defp format_error(%{"message" => msg}), do: msg
  defp format_error(%{"data" => %{"message" => msg}}), do: msg
  defp format_error(error), do: inspect(error)

  defp format_token_count(nil), do: "-"
  defp format_token_count(n) when is_number(n) and n >= 1000, do: "#{Float.round(n / 1000, 1)}k"
  defp format_token_count(n) when is_number(n), do: "#{n}"
  defp format_token_count(_), do: "-"

  defp truncate_instruction(instruction, max_length) do
    if String.length(instruction) > max_length do
      String.slice(instruction, 0, max_length) <> "..."
    else
      instruction
    end
  end

  defp subscribe_to_active_tasks(tasks) do
    tasks
    |> Enum.filter(&active_task?/1)
    |> Enum.each(&Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{&1.id}"))
  end

  defp active_task?(%{status: status}), do: status in ["pending", "starting", "running"]

  defp task_running?(nil), do: false
  defp task_running?(task), do: active_task?(task)

  defp task_deletable?(%{status: status}), do: status in ["completed", "failed", "cancelled"]
  defp task_deletable?(_), do: false

  defp session_deletable?(sessions, container_id) do
    case Enum.find(sessions, &(&1.container_id == container_id)) do
      %{latest_status: status} -> status in ["completed", "failed", "cancelled"]
      _ -> false
    end
  end

  defp resumable_task?(%{status: status, container_id: cid, session_id: sid})
       when status in ["completed", "failed", "cancelled"] and
              not is_nil(cid) and not is_nil(sid),
       do: true

  defp resumable_task?(_), do: false

  defp relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  # ---- Render ----

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-full">
      <%!-- Left Panel: Session List --%>
      <div class="w-72 shrink-0 border-r border-base-300 flex flex-col bg-base-100">
        <div class="p-3 border-b border-base-300">
          <button
            type="button"
            phx-click="new_session"
            class="btn btn-primary btn-sm w-full"
          >
            <.icon name="hero-plus" class="size-4" /> New Session
          </button>
        </div>

        <div class="flex-1 overflow-y-auto">
          <%= if @sessions == [] do %>
            <div class="p-6 text-center text-base-content/50 text-sm">
              <.icon name="hero-chat-bubble-left-right" class="size-8 mx-auto mb-2 opacity-40" />
              <p>No sessions yet</p>
            </div>
          <% else %>
            <ul class="menu menu-sm p-2 gap-1">
              <li :for={session <- @sessions}>
                <div
                  class={[
                    "flex flex-col items-start gap-0.5 w-full rounded-lg p-2",
                    session.container_id == @active_container_id && "active"
                  ]}
                  phx-click="select_session"
                  phx-value-container-id={session.container_id}
                >
                  <div class="flex items-center justify-between w-full">
                    <span class="text-xs font-medium truncate max-w-[10rem]">
                      {truncate_instruction(session.title, 35)}
                    </span>
                    <.status_dot status={session.latest_status} />
                  </div>
                  <div class="flex items-center gap-2 text-[0.65rem] text-base-content/50 w-full">
                    <span>{session.task_count} task{if session.task_count != 1, do: "s"}</span>
                    <span>&middot;</span>
                    <span>{relative_time(session.latest_at)}</span>
                  </div>
                </div>
              </li>
            </ul>
          <% end %>
        </div>
      </div>

      <%!-- Right Panel: Active Session Detail --%>
      <div class="flex-1 flex flex-col min-w-0 overflow-hidden">
        <%= if @active_container_id || @current_task || @composing_new do %>
          <%!-- Session header --%>
          <div class="px-4 py-3 border-b border-base-300 flex items-center justify-between bg-base-100 shrink-0">
            <div class="flex items-center gap-2 min-w-0">
              <.status_badge status={if @current_task, do: @current_task.status, else: "idle"} />
              <h2 class="text-sm font-medium truncate">
                {@session_title ||
                  if @current_task,
                    do: truncate_instruction(@current_task.instruction, 60),
                    else: "Session"}
              </h2>
            </div>
            <div class="flex items-center gap-2 shrink-0">
              <span
                :if={@session_model}
                class="text-xs text-base-content/50 font-mono"
              >
                {@session_model}
              </span>
              <button
                :if={@active_container_id && session_deletable?(@sessions, @active_container_id)}
                type="button"
                phx-click="delete_session"
                phx-value-container-id={@active_container_id}
                data-confirm="Delete this session and its container? This cannot be undone."
                class="btn btn-ghost btn-xs text-error"
                title="Delete session"
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </div>
          </div>

          <%!-- Stats bar --%>
          <div
            :if={@session_tokens || @session_summary}
            class="px-4 py-1.5 border-b border-base-300 flex flex-wrap gap-4 text-xs text-base-content/60 bg-base-100 shrink-0"
          >
            <div :if={@session_tokens} class="flex items-center gap-1">
              <.icon name="hero-arrow-down-tray" class="size-3" />
              <span>{format_token_count(@session_tokens["input"])} in</span>
            </div>
            <div :if={@session_tokens} class="flex items-center gap-1">
              <.icon name="hero-arrow-up-tray" class="size-3" />
              <span>{format_token_count(@session_tokens["output"])} out</span>
            </div>
            <div :if={@session_tokens && @session_tokens["cache"]} class="flex items-center gap-1">
              <.icon name="hero-circle-stack" class="size-3" />
              <span>{format_token_count(@session_tokens["cache"]["read"])} cached</span>
            </div>
            <div
              :if={@session_summary && @session_summary["files"] && @session_summary["files"] > 0}
              class="flex items-center gap-1"
            >
              <.icon name="hero-document-text" class="size-3" />
              <span>
                {Map.get(@session_summary, "files", 0)} files
                <span class="text-success">+{Map.get(@session_summary, "additions", 0)}</span>
                <span class="text-error">-{Map.get(@session_summary, "deletions", 0)}</span>
              </span>
            </div>
          </div>

          <%!-- Error alert --%>
          <div
            :if={@current_task && @current_task.status == "failed" && @current_task.error}
            class="mx-4 mt-3 alert alert-error"
          >
            <.icon name="hero-exclamation-triangle" class="size-5 shrink-0" />
            <div>
              <h3 class="font-semibold">Task failed</h3>
              <p class="text-sm">{format_error(@current_task.error)}</p>
            </div>
          </div>

          <%!-- Output log --%>
          <div class="flex-1 overflow-y-auto p-4" id="session-log" phx-hook="SessionLog">
            <%= if @output_parts == [] && task_running?(@current_task) do %>
              <div class="flex items-center gap-2 text-base-content/50 text-sm">
                <span class="loading loading-dots loading-xs"></span>
                <span>Waiting for response...</span>
              </div>
            <% end %>
            <%= if @output_parts == [] && !task_running?(@current_task) && @current_task == nil do %>
              <div class="flex flex-col items-center justify-center h-full text-base-content/40">
                <.icon name="hero-command-line" class="size-12 mb-3" />
                <p class="text-sm">Enter an instruction below to start</p>
              </div>
            <% end %>
            <%= for part <- @output_parts do %>
              <.output_part part={part} />
            <% end %>
          </div>

          <%!-- Task history for this session --%>
          <div
            :if={@active_container_id && length(session_tasks(@tasks, @active_container_id)) > 1}
            class="border-t border-base-300 shrink-0 max-h-40 overflow-y-auto"
          >
            <div class="px-4 py-2">
              <h4 class="text-xs font-semibold text-base-content/60 mb-1">Task History</h4>
              <div class="space-y-1">
                <div
                  :for={task <- session_tasks(@tasks, @active_container_id)}
                  class={[
                    "flex items-center gap-2 text-xs p-1.5 rounded cursor-pointer hover:bg-base-200",
                    @current_task && @current_task.id == task.id && "bg-base-200"
                  ]}
                  phx-click="view_task"
                  phx-value-task-id={task.id}
                >
                  <.status_dot status={task.status} />
                  <span class="truncate flex-1">{truncate_instruction(task.instruction, 45)}</span>
                  <span class="text-base-content/40 shrink-0">
                    {relative_time(task.inserted_at)}
                  </span>
                  <button
                    :if={task_deletable?(task)}
                    type="button"
                    phx-click="delete_task"
                    phx-value-task-id={task.id}
                    data-confirm="Delete this task?"
                    class="btn btn-ghost btn-xs p-0 min-h-0 h-auto"
                    title="Delete task"
                  >
                    <.icon name="hero-x-mark" class="size-3 text-base-content/30 hover:text-error" />
                  </button>
                </div>
              </div>
            </div>
          </div>

          <%!-- Input form --%>
          <div class="border-t border-base-300 p-3 bg-base-100 shrink-0">
            <form id="session-form" phx-submit="run_task" class="flex gap-2 items-end">
              <div class="flex-1">
                <textarea
                  name="instruction"
                  id="session-instruction"
                  phx-hook="SessionForm"
                  rows="2"
                  class="textarea textarea-bordered w-full text-sm leading-snug"
                  placeholder={
                    if resumable_task?(@current_task),
                      do: "Follow-up instruction...",
                      else: "Describe the coding task..."
                  }
                  disabled={task_running?(@current_task)}
                >{@form["instruction"].value}</textarea>
              </div>
              <div class="flex gap-1 shrink-0">
                <.button
                  :if={task_running?(@current_task)}
                  type="button"
                  variant="error"
                  size="sm"
                  phx-click="cancel_task"
                  id="cancel-task-btn"
                >
                  <.icon name="hero-stop" class="size-4" />
                </.button>
                <.button
                  type="submit"
                  variant="primary"
                  size="sm"
                  disabled={task_running?(@current_task)}
                >
                  <%= if resumable_task?(@current_task) do %>
                    <.icon name="hero-arrow-path" class="size-4" />
                  <% else %>
                    <.icon name="hero-paper-airplane" class="size-4" />
                  <% end %>
                </.button>
              </div>
            </form>
          </div>
        <% else %>
          <%!-- Empty state — no session selected --%>
          <div class="flex-1 flex flex-col items-center justify-center text-base-content/40 p-8">
            <.icon name="hero-command-line" class="size-16 mb-4" />
            <h3 class="text-lg font-semibold mb-2">No sessions yet</h3>
            <p class="text-sm text-center max-w-sm mb-4">
              Start a new coding session to run tasks in containers with opencode.
            </p>
            <button type="button" phx-click="new_session" class="btn btn-primary btn-sm">
              <.icon name="hero-plus" class="size-4" /> New Session
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ---- Components ----

  defp output_part(%{part: {:text, text}} = assigns) do
    assigns = assign(assigns, :rendered_html, render_markdown(text))

    ~H"""
    <div class="session-markdown py-1">{@rendered_html}</div>
    """
  end

  defp output_part(%{part: {:tool, name, status}} = assigns) do
    assigns = assign(assigns, :name, name)
    assigns = assign(assigns, :tool_status, status)

    ~H"""
    <div class="flex items-center gap-2 py-1 text-base-content/60 text-xs">
      <span :if={@tool_status == :running} class="loading loading-spinner loading-xs"></span>
      <.icon :if={@tool_status == :done} name="hero-check-circle" class="size-3 text-success" />
      <span>{@name}</span>
    </div>
    """
  end

  defp output_part(assigns) do
    ~H"""
    """
  end

  defp status_badge(%{status: "idle"} = assigns) do
    ~H"""
    <span class="badge badge-sm badge-ghost">idle</span>
    """
  end

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm",
      @status == "pending" && "badge-warning",
      @status == "starting" && "badge-warning",
      @status == "running" && "badge-info animate-pulse",
      @status == "completed" && "badge-success",
      @status == "failed" && "badge-error",
      @status == "cancelled" && "badge-ghost"
    ]}>
      {@status}
    </span>
    """
  end

  defp status_dot(assigns) do
    ~H"""
    <span class={[
      "inline-block size-2 rounded-full shrink-0",
      @status == "pending" && "bg-warning",
      @status == "starting" && "bg-warning",
      @status == "running" && "bg-info animate-pulse",
      @status == "completed" && "bg-success",
      @status == "failed" && "bg-error",
      @status == "cancelled" && "bg-base-content/30"
    ]}>
    </span>
    """
  end
end
