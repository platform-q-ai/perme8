defmodule JargaWeb.AppLive.Sessions.Index do
  @moduledoc """
  LiveView for running and managing coding sessions.

  Provides:
  - Instruction input form with "Run" button
  - Real-time event log via PubSub
  - Cancel button for running tasks
  - Task history with status indicators
  """

  use JargaWeb, :live_view

  import JargaWeb.ChatLive.MessageHandlers

  alias Agents.Sessions
  alias JargaWeb.Layouts

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
      {:noreply,
       socket
       |> put_flash(:error, "Instruction is required")}
    else
      user = socket.assigns.current_scope.user

      case Sessions.create_task(%{instruction: instruction, user_id: user.id}) do
        {:ok, task} ->
          Phoenix.PubSub.subscribe(Jarga.PubSub, "task:#{task.id}")

          {:noreply,
           socket
           |> assign(:current_task, task)
           |> assign(:events, [])
           |> assign(:form, to_form(%{"instruction" => ""}))
           |> reload_tasks()}

        {:error, :concurrent_limit_reached} ->
          {:noreply, put_flash(socket, :error, "A task is already running")}

        {:error, :instruction_required} ->
          {:noreply, put_flash(socket, :error, "Instruction is required")}

        {:error, _changeset} ->
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

        case Sessions.cancel_task(task.id, user.id) do
          :ok ->
            {:noreply, put_flash(socket, :info, "Task cancelled")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to cancel task")}
        end
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
         |> assign(:events, [])}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Task not found")}
    end
  end

  @impl true
  def handle_info({:task_event, _task_id, event}, socket) do
    events = socket.assigns.events ++ [event]

    {:noreply,
     socket
     |> assign(:events, events)}
  end

  @impl true
  def handle_info({:task_status_changed, task_id, status}, socket) do
    current_task = socket.assigns.current_task

    updated_task =
      if current_task && current_task.id == task_id do
        if status == "failed" do
          # Reload from DB to get the error message
          user = socket.assigns.current_scope.user

          case Sessions.get_task(task_id, user.id) do
            {:ok, %{error: error} = task} when not is_nil(error) -> task
            _ -> Map.put(current_task, :status, status)
          end
        else
          Map.put(current_task, :status, status)
        end
      else
        current_task
      end

    {:noreply,
     socket
     |> assign(:current_task, updated_task)
     |> reload_tasks()}
  end

  # Chat panel streaming messages
  handle_chat_messages()

  defp reload_tasks(socket) do
    user = socket.assigns.current_scope.user
    tasks = Sessions.list_tasks(user.id)
    assign(socket, :tasks, tasks)
  end

  defp format_event_component(%{event: %{"type" => type} = event} = assigns) do
    content =
      get_in(event, ["data", "content"]) ||
        get_in(event, ["properties", "content"]) ||
        inspect(event["properties"] || event["data"])

    assigns = assign(assigns, :type, type)
    assigns = assign(assigns, :content, content)

    ~H"""
    <span class="text-base-content/50 font-mono text-xs">[{@type}]</span> {@content}
    """
  end

  defp format_event_component(assigns) do
    assigns = assign(assigns, :raw, inspect(assigns.event))

    ~H"""
    <span class="font-mono text-xs">{@raw}</span>
    """
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(%{"message" => msg}), do: msg
  defp format_error(%{"data" => %{"message" => msg}}), do: msg
  defp format_error(error), do: inspect(error)

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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <.header>
          Sessions
          <:subtitle>Run coding tasks in ephemeral containers</:subtitle>
        </.header>

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
                  rows="3"
                  class="textarea textarea-bordered w-full"
                  placeholder="Describe the coding task..."
                  disabled={task_running?(@current_task)}
                >{@form["instruction"].value}</textarea>
              </div>
              <div class="mt-4 flex items-center gap-3">
                <.button
                  type="submit"
                  variant="primary"
                  disabled={task_running?(@current_task)}
                >
                  <.icon name="hero-play" class="size-4" /> Run
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

        <%!-- Event Log --%>
        <div :if={@current_task} class="card bg-base-200">
          <div class="card-body">
            <h3 class="card-title text-sm">
              Event Log <.status_badge status={@current_task.status} />
            </h3>
            <div
              id="session-log"
              phx-hook="SessionLog"
              class="bg-base-300 rounded-lg p-4 h-64 overflow-y-auto font-mono text-sm"
            >
              <div :for={event <- @events} class="py-1 text-sm">
                <.format_event_component event={event} />
              </div>
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
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </Layouts.admin>
    """
  end

  @doc false
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
