defmodule AgentsWeb.SessionsLive.Index do
  @moduledoc """
  LiveView for running and managing coding sessions.

  Provides:
  - Instruction input form with "Run" button
  - Real-time event log via PubSub
  - Cancel button for running tasks
  - Task history with status indicators
  """

  use AgentsWeb, :live_view

  alias Agents.Sessions

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    tasks = Sessions.list_tasks(user.id)

    if connected?(socket), do: subscribe_to_active_tasks(tasks)

    current_task = Enum.find(tasks, &active_task?/1)

    {:ok,
     socket
     |> assign(:page_title, "Sessions")
     |> assign(:tasks, tasks)
     |> assign(:current_task, current_task)
     |> assign(:events, [])
     |> assign_session_state()
     |> assign(:form, to_form(%{"instruction" => ""}))}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("run_task", %{"instruction" => instruction}, socket) do
    instruction = String.trim(instruction)

    if instruction == "" do
      {:noreply, put_flash(socket, :error, "Instruction is required")}
    else
      user = socket.assigns.current_scope.user
      current_task = socket.assigns.current_task

      # If viewing a completed task with a container, resume it; otherwise create new
      result =
        if resumable_task?(current_task) do
          Sessions.resume_task(current_task.id, %{instruction: instruction, user_id: user.id})
        else
          Sessions.create_task(%{instruction: instruction, user_id: user.id})
        end

      case result do
        {:ok, task} ->
          Phoenix.PubSub.subscribe(Jarga.PubSub, "task:#{task.id}")

          {:noreply,
           socket
           |> assign(:current_task, task)
           |> assign(:events, [])
           |> assign_session_state()
           |> assign(:form, to_form(%{"instruction" => ""}))
           |> reload_tasks()}

        {:error, :concurrent_limit_reached} ->
          {:noreply, put_flash(socket, :error, "A task is already running")}

        {:error, :instruction_required} ->
          {:noreply, put_flash(socket, :error, "Instruction is required")}

        {:error, :not_resumable} ->
          {:noreply, put_flash(socket, :error, "This session cannot be resumed")}

        {:error, :no_container} ->
          {:noreply, put_flash(socket, :error, "No container available for resume")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to create task")}
      end
    end
  end

  @impl true
  def handle_event("cancel_task", _params, socket) do
    case socket.assigns.current_task do
      nil ->
        {:noreply, socket}

      task ->
        user = socket.assigns.current_scope.user
        do_cancel_task(task, user, socket)
    end
  end

  @impl true
  def handle_event("delete_task", %{"task-id" => task_id}, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.delete_task(task_id, user.id) do
      :ok ->
        current_task = socket.assigns.current_task

        socket =
          if current_task && current_task.id == task_id do
            socket
            |> assign(:current_task, nil)
            |> assign_session_state()
          else
            socket
          end

        {:noreply,
         socket
         |> reload_tasks()
         |> put_flash(:info, "Session deleted")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete session")}
    end
  end

  @impl true
  def handle_event("view_task", %{"task-id" => task_id}, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.get_task(task_id, user.id) do
      {:ok, task} ->
        if task.status in ["pending", "starting", "running"] do
          Phoenix.PubSub.subscribe(Jarga.PubSub, "task:#{task.id}")
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

  # ---- handle_event helpers ----

  defp do_cancel_task(task, user, socket) do
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
         |> reload_tasks()
         |> put_flash(:info, "Task cancelled")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel task")}
    end
  end

  # ---- handle_info callbacks ----

  @impl true
  def handle_info({:task_event, _task_id, event}, socket) do
    {:noreply, process_event(event, socket)}
  end

  @impl true
  def handle_info({:task_status_changed, task_id, status}, socket) do
    current_task = socket.assigns.current_task
    updated_task = maybe_update_task_status(current_task, task_id, status, socket)

    socket =
      socket
      |> assign(:current_task, updated_task)
      |> update_task_in_list(task_id, status)

    # Only do a full reload from DB on terminal status changes
    socket =
      if status in ["completed", "failed", "cancelled"] do
        reload_tasks(socket)
      else
        socket
      end

    {:noreply, socket}
  end

  # Catch-all for unhandled messages
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

  defp maybe_update_task_status(task, _task_id, status, _socket) do
    Map.put(task, :status, status)
  end

  # ---- Session state management ----

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

  # ---- Cached output loading ----

  defp maybe_load_cached_output(socket, %{output: output})
       when is_binary(output) and output != "" do
    assign(socket, :output_parts, [{:text, output}])
  end

  defp maybe_load_cached_output(socket, _task), do: socket

  # ---- Helpers ----

  defp update_task_in_list(socket, task_id, status) do
    tasks =
      Enum.map(socket.assigns.tasks, fn
        %{id: ^task_id} = task -> Map.put(task, :status, status)
        task -> task
      end)

    assign(socket, :tasks, tasks)
  end

  defp reload_tasks(socket) do
    user = socket.assigns.current_scope.user
    tasks = Sessions.list_tasks(user.id)
    assign(socket, :tasks, tasks)
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
      {:ok, html} -> Phoenix.HTML.raw(MDEx.safe_html(html))
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

  defp truncate_instruction(instruction, max_length \\ 80) do
    if String.length(instruction) > max_length do
      String.slice(instruction, 0, max_length) <> "..."
    else
      instruction
    end
  end

  defp subscribe_to_active_tasks(tasks) do
    tasks
    |> Enum.filter(&active_task?/1)
    |> Enum.each(&Phoenix.PubSub.subscribe(Jarga.PubSub, "task:#{&1.id}"))
  end

  defp active_task?(%{status: status}), do: status in ["pending", "starting", "running"]

  defp task_running?(nil), do: false
  defp task_running?(task), do: active_task?(task)

  defp task_deletable?(%{status: status}), do: status in ["completed", "failed", "cancelled"]
  defp task_deletable?(_), do: false

  defp resumable_task?(%{status: status, container_id: cid, session_id: sid})
       when status in ["completed", "failed", "cancelled"] and
              not is_nil(cid) and not is_nil(sid),
       do: true

  defp resumable_task?(_), do: false

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        Sessions
        <:subtitle>Run coding tasks in containers</:subtitle>
      </.header>

      <.flash :if={@flash != %{}} kind={:info} flash={@flash} />
      <.flash :if={@flash != %{}} kind={:error} flash={@flash} />

      <%!-- Instruction Form --%>
      <div class="card bg-base-200">
        <div class="card-body">
          <form id="session-form" phx-submit="run_task">
            <div class="form-control">
              <label class="label" for="session-instruction">
                <span class="label-text font-medium">Instruction</span>
              </label>
              <textarea
                name="instruction"
                id="session-instruction"
                phx-hook="SessionForm"
                rows="3"
                class="textarea textarea-bordered w-full"
                placeholder={
                  if resumable_task?(@current_task),
                    do: "Follow-up instruction...",
                    else: "Describe the coding task..."
                }
                disabled={task_running?(@current_task)}
              >{@form["instruction"].value}</textarea>
            </div>
            <div class="mt-4 flex items-center gap-3">
              <.button
                type="submit"
                variant="primary"
                disabled={task_running?(@current_task)}
              >
                <%= if resumable_task?(@current_task) do %>
                  <.icon name="hero-arrow-path" class="size-4" /> Resume
                <% else %>
                  <.icon name="hero-play" class="size-4" /> Run
                <% end %>
              </.button>
              <.button
                :if={task_running?(@current_task)}
                type="button"
                variant="error"
                phx-click="cancel_task"
                id="cancel-task-btn"
              >
                <.icon name="hero-stop" class="size-4" /> Cancel
              </.button>
            </div>
          </form>
        </div>
      </div>

      <%!-- Error Alert --%>
      <div
        :if={@current_task && @current_task.status == "failed" && @current_task.error}
        class="alert alert-error"
        id="task-error"
      >
        <.icon name="hero-exclamation-triangle" class="size-5 shrink-0" />
        <div>
          <h3 class="font-semibold">Task failed</h3>
          <p class="text-sm">{format_error(@current_task.error)}</p>
        </div>
      </div>

      <%!-- Session Panel --%>
      <div :if={@current_task} class="card bg-base-200">
        <div class="card-body space-y-4">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-2">
              <.status_badge status={@current_task.status} />
              <h3 :if={@session_title} class="font-medium text-sm" id="session-title">
                {@session_title}
              </h3>
            </div>
            <span
              :if={@session_model}
              class="text-xs text-base-content/50 font-mono"
              id="session-model"
            >
              {@session_model}
            </span>
          </div>

          <div
            :if={@session_tokens || @session_summary}
            class="flex flex-wrap gap-4 text-xs text-base-content/60"
            id="session-stats"
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

          <div
            id="session-log"
            phx-hook="SessionLog"
            class="bg-base-300 rounded-lg p-4 min-h-32 max-h-96 overflow-y-auto font-mono text-sm"
          >
            <%= if @output_parts == [] && task_running?(@current_task) do %>
              <div class="flex items-center gap-2 text-base-content/50">
                <span class="loading loading-dots loading-xs"></span>
                <span>Waiting for response...</span>
              </div>
            <% end %>
            <%= for part <- @output_parts do %>
              <.output_part part={part} />
            <% end %>
          </div>
        </div>
      </div>

      <%!-- Task History --%>
      <%= if @tasks == [] do %>
        <div class="card bg-base-200">
          <div class="card-body text-center">
            <div class="flex flex-col items-center gap-4 py-8">
              <.icon name="hero-command-line" class="size-16 opacity-50" />
              <div>
                <h3 class="text-base font-semibold">No sessions yet</h3>
                <p class="text-base-content/70">
                  Enter an instruction above and click Run to start a coding session
                </p>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <div class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-sm">History</h3>
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th class="text-sm font-semibold">Instruction</th>
                    <th class="text-sm font-semibold">Status</th>
                    <th class="text-sm font-semibold">Created</th>
                    <th class="text-sm font-semibold w-10"></th>
                  </tr>
                </thead>
                <tbody>
                  <%= for task <- @tasks do %>
                    <tr
                      class="cursor-pointer hover"
                      phx-click="view_task"
                      phx-value-task-id={task.id}
                    >
                      <td class="text-sm">{truncate_instruction(task.instruction)}</td>
                      <td><.status_badge status={task.status} /></td>
                      <td class="text-sm text-base-content/70">
                        {Calendar.strftime(task.inserted_at, "%Y-%m-%d %H:%M")}
                      </td>
                      <td>
                        <button
                          :if={task_deletable?(task)}
                          type="button"
                          phx-click="delete_task"
                          phx-value-task-id={task.id}
                          data-confirm="Delete this session?"
                          class="btn btn-ghost btn-xs"
                          title="Delete"
                        >
                          <.icon
                            name="hero-trash"
                            class="size-4 text-base-content/40 hover:text-error"
                          />
                        </button>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

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
end
