defmodule AgentsWeb.SessionsLive.Index do
  @moduledoc "LiveView for the session manager — split-panel layout with session list, output log, and task controls."

  use AgentsWeb, :live_view

  import AgentsWeb.SessionsLive.Components.SessionComponents
  import AgentsWeb.SessionsLive.Helpers

  alias Agents.Sessions
  alias Agents.Sessions.Domain.Entities.TodoList
  alias AgentsWeb.SessionsLive.EventProcessor

  @stats_interval_ms 5_000

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    sessions = Sessions.list_sessions(user.id)
    tasks = Sessions.list_tasks(user.id)

    if connected?(socket) do
      subscribe_to_active_tasks(tasks)
      schedule_stats_poll()
    end

    active_container_id =
      case sessions do
        [first | _] -> first.container_id
        [] -> nil
      end

    current_task = find_current_task(tasks, active_container_id)

    available_images = Sessions.available_images()
    default_image = Sessions.default_image()

    {:ok,
     socket
     |> assign(:page_title, "Sessions")
     |> assign(:full_width, true)
     |> assign(:sessions, sessions)
     |> assign(:tasks, tasks)
     |> assign(:active_container_id, active_container_id)
     |> assign(:current_task, current_task)
     |> assign(:composing_new, false)
     |> assign(:container_stats, %{})
     |> assign(:auth_refreshing, false)
     |> assign(:events, [])
     |> assign(:available_images, available_images)
     |> assign(:selected_image, default_image)
     |> assign_session_state()
     |> assign(:form, to_form(%{"instruction" => ""}))
     |> EventProcessor.maybe_load_cached_output(current_task)
     |> EventProcessor.maybe_load_pending_question(current_task)
     |> EventProcessor.maybe_load_todos(current_task)}
  end

  @impl true
  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("run_task", %{"instruction" => instruction}, socket) do
    instruction = String.trim(instruction)

    cond do
      instruction == "" ->
        {:noreply, put_flash(socket, :error, "Instruction is required")}

      task_running?(socket.assigns.current_task) ->
        send_message_to_running_task(socket, instruction)

      true ->
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
  def handle_event("refresh_auth_and_resume", _params, socket) do
    case socket.assigns.current_task do
      %{id: task_id} when is_binary(task_id) ->
        user = socket.assigns.current_scope.user
        Task.async(fn -> Sessions.refresh_auth_and_resume(task_id, user.id) end)

        {:noreply,
         socket
         |> assign(:auth_refreshing, true)
         |> put_flash(:info, "Refreshing auth and restarting container...")}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("new_session", _params, socket) do
    {:noreply,
     socket
     |> assign(:active_container_id, nil)
     |> assign(:current_task, nil)
     |> assign(:composing_new, true)
     |> assign(:selected_image, Sessions.default_image())
     |> assign(:events, [])
     |> assign_session_state()
     |> assign(:form, to_form(%{"instruction" => ""}))}
  end

  @impl true
  def handle_event("select_image", %{"image" => image}, socket) do
    {:noreply, assign(socket, :selected_image, image)}
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
     |> EventProcessor.maybe_load_cached_output(current_task)
     |> EventProcessor.maybe_load_pending_question(current_task)
     |> EventProcessor.maybe_load_todos(current_task)}
  end

  @impl true
  def handle_event("delete_session", %{"container-id" => container_id}, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.delete_session(container_id, user.id) do
      :ok ->
        socket =
          if socket.assigns.active_container_id == container_id,
            do:
              socket
              |> assign(:active_container_id, nil)
              |> assign(:current_task, nil)
              |> assign(:events, [])
              |> assign_session_state(),
            else: socket

        {:noreply, socket |> reload_all(user.id) |> put_flash(:info, "Session deleted")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete session")}
    end
  end

  @impl true
  def handle_event(
        "toggle_question_option",
        %{"question-index" => q_idx_str, "label" => label},
        socket
      ) do
    case socket.assigns.pending_question do
      nil ->
        {:noreply, socket}

      pending ->
        q_idx = String.to_integer(q_idx_str)
        multiple = Enum.at(pending.questions, q_idx)["multiple"] || false
        current = Enum.at(pending.selected, q_idx, [])

        updated =
          List.replace_at(pending.selected, q_idx, toggle_selection(current, label, multiple))

        {:noreply, assign(socket, :pending_question, %{pending | selected: updated})}
    end
  end

  @impl true
  def handle_event("update_question_form", %{"custom_answer" => custom_map}, socket) do
    case socket.assigns.pending_question do
      nil ->
        {:noreply, socket}

      pending ->
        updated =
          pending.custom_text
          |> Enum.with_index()
          |> Enum.map(fn {_old, idx} -> Map.get(custom_map, to_string(idx), "") end)

        {:noreply, assign(socket, :pending_question, %{pending | custom_text: updated})}
    end
  end

  @impl true
  def handle_event("update_question_form", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("submit_question_answer", _params, socket) do
    case {socket.assigns.pending_question, socket.assigns.current_task} do
      {nil, _} ->
        {:noreply, socket}

      {%{rejected: true} = pending, %{id: task_id}} ->
        {:noreply, submit_rejected_question(socket, pending, task_id)}

      {pending, %{id: task_id}} ->
        {:noreply, submit_active_question(socket, pending, task_id)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("dismiss_question", _params, socket) do
    case {socket.assigns.pending_question, socket.assigns.current_task} do
      {nil, _} ->
        {:noreply, socket}

      {%{rejected: true}, _} ->
        {:noreply, assign(socket, :pending_question, nil)}

      {pending, %{id: task_id}} ->
        Sessions.reject_question(task_id, pending.request_id)
        {:noreply, assign(socket, :pending_question, %{pending | rejected: true})}

      _ ->
        {:noreply, socket}
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
         |> EventProcessor.maybe_load_cached_output(task)
         |> EventProcessor.maybe_load_pending_question(task)
         |> EventProcessor.maybe_load_todos(task)}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Task not found")}
    end
  end

  @impl true
  def handle_info({:task_event, task_id, event}, socket) do
    case socket.assigns.current_task do
      %{id: ^task_id} -> {:noreply, EventProcessor.process_event(event, socket)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:todo_updated, task_id, todo_items}, socket) do
    case socket.assigns.current_task do
      %{id: ^task_id} when is_list(todo_items) ->
        todo_list = TodoList.from_maps(todo_items)

        {:noreply, assign(socket, :todo_items, EventProcessor.todo_items_for_assigns(todo_list))}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:task_status_changed, task_id, status}, socket) do
    updated_task = maybe_update_task_status(socket.assigns.current_task, task_id, status, socket)

    cid =
      if(updated_task && updated_task.container_id,
        do: updated_task.container_id,
        else: socket.assigns.active_container_id
      )

    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:current_task, updated_task)
      |> assign(:active_container_id, cid)
      |> do_update_task_in_list(task_id, status)
      |> reload_all(user.id)

    socket =
      cond do
        status in ["completed", "failed"] ->
          socket
          |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
          |> assign(:pending_question, nil)
          |> assign(:queued_messages, [])

        status == "cancelled" ->
          socket
          |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
          |> assign(:pending_question, nil)

        true ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:poll_container_stats, socket) do
    stats = poll_running_session_stats(socket.assigns.sessions)
    schedule_stats_poll()
    {:noreply, assign(socket, :container_stats, stats)}
  end

  @impl true
  def handle_info({ref, {:ok, new_task}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{new_task.id}")
    user = socket.assigns.current_scope.user

    {:noreply,
     socket
     |> assign(:current_task, new_task)
     |> assign(:auth_refreshing, false)
     |> assign(:events, [])
     |> assign_session_state()
     |> assign(:form, to_form(%{"instruction" => ""}))
     |> clear_flash()
     |> reload_all(user.id)}
  end

  @impl true
  def handle_info({ref, {:error, reason}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     socket
     |> assign(:auth_refreshing, false)
     |> clear_flash()
     |> put_flash(:error, task_error_message(reason))}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, socket), do: {:noreply, socket}

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp assign_session_state(socket) do
    assign(socket,
      session_title: nil,
      session_model: nil,
      session_tokens: nil,
      session_cost: nil,
      session_summary: nil,
      output_parts: [],
      pending_question: nil,
      user_message_ids: MapSet.new(),
      todo_items: [],
      queued_messages: []
    )
  end

  defp send_message_to_running_task(socket, instruction) do
    case Sessions.send_message(socket.assigns.current_task.id, instruction) do
      :ok ->
        queued_msg = %{
          id: Ecto.UUID.generate(),
          content: instruction,
          queued_at: DateTime.utc_now()
        }

        {:noreply,
         socket
         |> assign(:queued_messages, socket.assigns.queued_messages ++ [queued_msg])
         |> assign(:form, to_form(%{"instruction" => ""}))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to send message")}
    end
  end

  defp toggle_selection(current, label, true = _multiple) do
    if label in current, do: List.delete(current, label), else: current ++ [label]
  end

  defp toggle_selection(current, label, false = _single) do
    if label in current, do: [], else: [label]
  end

  defp build_question_answers(pending) do
    Enum.zip(pending.selected, pending.custom_text)
    |> Enum.map(fn {selected, custom} ->
      custom_trimmed = String.trim(custom)
      if custom_trimmed != "", do: selected ++ [custom_trimmed], else: selected
    end)
  end

  defp format_question_answer_as_message(pending, answers) do
    Enum.zip(pending.questions, answers)
    |> Enum.map_join("\n", fn {question, answer_list} ->
      header = question["header"] || "Question"
      "Re: #{header} — #{Enum.join(answer_list, ", ")}"
    end)
  end

  defp submit_rejected_question(socket, pending, task_id) do
    message = format_question_answer_as_message(pending, build_question_answers(pending))

    Sessions.send_message(task_id, message)
    |> handle_question_result(socket, pending, "Failed to send message — please try again")
  end

  defp submit_active_question(socket, pending, task_id) do
    Sessions.answer_question(task_id, pending.request_id, build_question_answers(pending))
    |> handle_question_result(socket, pending, "Failed to submit answer — please try again")
  end

  defp handle_question_result(:ok, socket, _pending, _error_msg) do
    assign(socket, :pending_question, nil)
  end

  defp handle_question_result({:error, :task_not_running}, socket, pending, _error_msg) do
    message = format_question_answer_as_message(pending, build_question_answers(pending))

    socket
    |> assign(:pending_question, nil)
    |> assign(:form, to_form(%{"instruction" => message}))
    |> put_flash(:info, "Session ended. Your answer is in the input — submit to resume.")
  end

  defp handle_question_result({:error, _}, socket, _pending, error_msg) do
    socket |> assign(:pending_question, nil) |> put_flash(:error, error_msg)
  end

  defp run_or_resume_task(socket, instruction) do
    user = socket.assigns.current_scope.user
    current_task = socket.assigns.current_task

    if resumable_task?(current_task) do
      Sessions.resume_task(current_task.id, %{instruction: instruction, user_id: user.id})
    else
      Sessions.create_task(%{
        instruction: instruction,
        user_id: user.id,
        image: socket.assigns.selected_image
      })
    end
  end

  defp handle_task_result({:ok, task}, socket) do
    user = socket.assigns.current_scope.user
    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

    {:noreply,
     socket
     |> assign(:current_task, task)
     |> assign(:active_container_id, task.container_id || socket.assigns.active_container_id)
     |> assign(:composing_new, false)
     |> assign(:events, [])
     |> assign_session_state()
     |> assign(:form, to_form(%{"instruction" => ""}))
     |> reload_all(user.id)}
  end

  defp handle_task_result({:error, reason}, socket) do
    {:noreply, put_flash(socket, :error, task_error_message(reason))}
  end

  defp do_cancel_task(task, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.cancel_task(task.id, user.id) do
      :ok ->
        updated =
          case Sessions.get_task(task.id, user.id) do
            {:ok, t} -> t
            _ -> Map.put(task, :status, "cancelled")
          end

        {:noreply,
         socket
         |> assign(:current_task, updated)
         |> reload_all(user.id)
         |> put_flash(:info, "Task cancelled")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel task")}
    end
  end

  defp maybe_update_task_status(nil, _task_id, _status, _socket), do: nil

  defp maybe_update_task_status(%{id: id} = task, task_id, _status, _socket) when id != task_id,
    do: task

  defp maybe_update_task_status(task, task_id, status, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.get_task(task_id, user.id) do
      {:ok, %{error: error} = refreshed} when status == "failed" and not is_nil(error) ->
        refreshed

      {:ok, refreshed} ->
        refreshed

      _ ->
        Map.put(task, :status, status)
    end
  end

  defp do_update_task_in_list(socket, task_id, status) do
    tasks = update_task_in_list(socket.assigns.tasks, task_id, status)
    assign(socket, :tasks, tasks)
  end

  defp reload_all(socket, user_id) do
    sessions = Sessions.list_sessions(user_id)
    tasks = Sessions.list_tasks(user_id)
    socket |> assign(:sessions, sessions) |> assign(:tasks, tasks)
  end

  defp subscribe_to_active_tasks(tasks) do
    tasks
    |> Enum.filter(&active_task?/1)
    |> Enum.each(&Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{&1.id}"))
  end

  defp schedule_stats_poll do
    Process.send_after(self(), :poll_container_stats, @stats_interval_ms)
  end
end
