defmodule AgentsWeb.SessionsLive.Index do
  @moduledoc "LiveView for the session manager — split-panel layout with session list, output log, and task controls."

  use AgentsWeb, :live_view

  import AgentsWeb.SessionsLive.Components.SessionComponents
  import AgentsWeb.SessionsLive.Helpers

  alias Agents.Sessions
  alias Agents.Sessions.Domain.Entities.TodoList
  alias AgentsWeb.SessionsLive.EventProcessor

  @stats_interval_ms 5_000
  @duration_tick_ms 1_000

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    sessions = Sessions.list_sessions(user.id)
    tasks = Sessions.list_tasks(user.id)

    if connected?(socket) do
      subscribe_to_active_tasks(tasks)
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "queue:user:#{user.id}")
      schedule_stats_poll()
      schedule_duration_tick()
    end

    available_images = Sessions.available_images()
    default_image = Sessions.default_image()

    sessions = merge_unassigned_active_tasks(sessions, tasks)

    {:ok,
     socket
     |> assign(:page_title, "Sessions")
     |> assign(:full_width, true)
     |> assign(:sessions, sessions)
     |> assign(:tasks_snapshot, tasks)
     |> assign(:composing_new, false)
     |> assign(:active_session_tab, "chat")
     |> assign(:container_stats, %{})
     |> assign(:duration_now, DateTime.utc_now())
     |> assign(:auth_refreshing, %{})
     |> assign(:events, [])
     |> assign(:available_images, available_images)
     |> assign(:selected_image, default_image)
     |> assign(:queue_state, load_queue_state(user.id))
     |> assign_session_state()
     |> assign(:form, to_form(%{"instruction" => ""}))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    tab = params["tab"] || "chat"
    valid_tabs = Enum.map(session_tabs(), & &1.id)
    active_tab = if tab in valid_tabs, do: tab, else: "chat"
    {:noreply, assign(socket, :active_session_tab, active_tab)}
  end

  @doc false
  def session_tabs do
    [%{id: "chat", label: "Chat"}]
  end

  @impl true
  def handle_event("run_task", %{"instruction" => instruction}, socket) do
    instruction = String.trim(instruction)

    cond do
      instruction == "" ->
        {:noreply, put_flash(socket, :error, "Instruction is required")}

      task_running?(socket.assigns.current_task) ->
        send_message_to_running_task(socket, instruction)

      true ->
        socket =
          if resumable_task?(socket.assigns.current_task) do
            append_optimistic_user_message(socket, instruction)
          else
            socket
          end

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
  def handle_event("refresh_auth_and_resume", params, socket) do
    task_id = params["task-id"] || (socket.assigns.current_task && socket.assigns.current_task.id)

    cond do
      is_nil(task_id) ->
        {:noreply, socket}

      Map.has_key?(socket.assigns.auth_refreshing, task_id) ->
        # Already refreshing this session
        {:noreply, socket}

      true ->
        user = socket.assigns.current_scope.user

        async =
          Task.async(fn -> {task_id, Sessions.refresh_auth_and_resume(task_id, user.id)} end)

        {:noreply,
         socket
         |> assign(
           :auth_refreshing,
           Map.put(socket.assigns.auth_refreshing, task_id, async.ref)
         )
         |> put_flash(:info, "Refreshing auth and restarting container...")}
    end
  end

  @impl true
  def handle_event("refresh_all_auth", _params, socket) do
    user = socket.assigns.current_scope.user
    tasks = Sessions.list_tasks(user.id)

    refreshable =
      Enum.filter(tasks, fn t ->
        t.status == "failed" and auth_error?(t.error) and resumable_task?(t) and
          not Map.has_key?(socket.assigns.auth_refreshing, t.id)
      end)

    socket =
      Enum.reduce(refreshable, socket, fn t, acc ->
        async = Task.async(fn -> {t.id, Sessions.refresh_auth_and_resume(t.id, user.id)} end)
        assign(acc, :auth_refreshing, Map.put(acc.assigns.auth_refreshing, t.id, async.ref))
      end)

    flash_msg =
      case length(refreshable) do
        0 -> "No sessions need auth refresh"
        n -> "Refreshing auth for #{n} session(s)..."
      end

    {:noreply, put_flash(socket, :info, flash_msg)}
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
     |> assign(:form, to_form(%{"instruction" => ""}))
     |> push_patch(to: ~p"/sessions?#{%{new: true}}")
     |> push_event("focus_input", %{})}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    valid_tabs = Enum.map(session_tabs(), & &1.id)
    tab = if tab in valid_tabs, do: tab, else: "chat"
    {:noreply, push_patch(socket, to: ~p"/sessions?#{%{tab: tab}}")}
  end

  @impl true
  def handle_event("update_concurrency_limit", %{"concurrency_limit" => limit_str}, socket) do
    user = socket.assigns.current_scope.user

    case Integer.parse(limit_str) do
      {limit, ""} when limit >= 1 and limit <= 5 ->
        Sessions.set_concurrency_limit(user.id, limit)
        # Queue state will be updated via PubSub broadcast from QueueManager
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_image", %{"image" => image}, socket) do
    {:noreply, assign(socket, :selected_image, image)}
  end

  @impl true
  def handle_event("select_session", %{"container-id" => container_id}, socket) do
    {:noreply,
     socket
     |> assign(:composing_new, false)
     |> assign(:events, [])
     |> assign_session_state()
     |> assign(:form, to_form(%{"instruction" => ""}))
     |> push_patch(to: ~p"/sessions?#{%{container: container_id}}")}
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
  def handle_info({:task_event, task_id, event}, socket) do
    case socket.assigns.current_task do
      %{id: ^task_id} ->
        socket =
          event
          |> EventProcessor.process_event(socket)
          |> maybe_sync_status_from_session_event(event, task_id)

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:todo_updated, task_id, todo_items}, socket) do
    case socket.assigns.current_task do
      %{id: ^task_id, container_id: container_id} when is_list(todo_items) ->
        todo_list = TodoList.from_maps(todo_items)

        sessions =
          update_session_todo_items(
            socket.assigns.sessions,
            container_id,
            TodoList.to_maps(todo_list)
          )

        {:noreply,
         socket
         |> assign(:todo_items, EventProcessor.todo_items_for_assigns(todo_list))
         |> assign(:sessions, sessions)}

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

    # Restart duration tick when a session begins running (it self-stops when
    # no running sessions exist, so we need to re-schedule here).
    if status == "running", do: schedule_duration_tick()

    {:noreply, socket}
  end

  @impl true
  def handle_info(:poll_container_stats, socket) do
    stats = poll_running_session_stats(socket.assigns.sessions)
    schedule_stats_poll()
    {:noreply, assign(socket, :container_stats, stats)}
  end

  @impl true
  def handle_info(:tick_session_durations, socket) do
    has_running =
      Enum.any?(socket.assigns.sessions, fn s ->
        s.started_at != nil and s.completed_at == nil
      end)

    if has_running, do: schedule_duration_tick()
    {:noreply, assign(socket, :duration_now, DateTime.utc_now())}
  end

  # Tagged async result from per-session auth refresh (success)
  @impl true
  def handle_info({ref, {task_id, {:ok, new_task}}}, socket)
      when is_reference(ref) and is_binary(task_id) do
    Process.demonitor(ref, [:flush])
    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{new_task.id}")
    user = socket.assigns.current_scope.user

    socket =
      assign(socket, :auth_refreshing, Map.delete(socket.assigns.auth_refreshing, task_id))

    # Only update the detail pane if this is the currently viewed session
    socket =
      if match?(%{id: ^task_id}, socket.assigns.current_task) do
        is_resume = match?(%{id: id} when id == new_task.id, socket.assigns.current_task)

        socket =
          socket
          |> assign(:current_task, new_task)
          |> assign(:events, [])
          |> assign(:form, to_form(%{"instruction" => ""}))

        if is_resume do
          socket
          |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
          |> assign(:pending_question, nil)
        else
          assign_session_state(socket)
        end
      else
        socket
      end

    {:noreply, reload_all(socket, user.id)}
  end

  # Tagged async result from per-session auth refresh (error)
  @impl true
  def handle_info({ref, {task_id, {:error, reason}}}, socket)
      when is_reference(ref) and is_binary(task_id) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     socket
     |> assign(:auth_refreshing, Map.delete(socket.assigns.auth_refreshing, task_id))
     |> put_flash(:error, "Session refresh failed: #{task_error_message(reason)}")}
  end

  # Untagged async result (from run_or_resume_task — not auth refresh)
  @impl true
  def handle_info({ref, {:ok, new_task}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{new_task.id}")
    user = socket.assigns.current_scope.user

    is_resume = match?(%{id: id} when id == new_task.id, socket.assigns.current_task)

    socket =
      socket
      |> assign(:current_task, new_task)
      |> assign(:events, [])
      |> assign(:form, to_form(%{"instruction" => ""}))
      |> clear_flash()

    socket =
      if is_resume do
        socket
        |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
        |> assign(:pending_question, nil)
      else
        assign_session_state(socket)
      end

    {:noreply, reload_all(socket, user.id)}
  end

  @impl true
  def handle_info({ref, {:error, reason}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     socket
     |> clear_flash()
     |> put_flash(:error, task_error_message(reason))}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:queue_updated, user_id, queue_state}, socket) do
    if user_id == socket.assigns.current_scope.user.id do
      {:noreply, assign(socket, :queue_state, queue_state)}
    else
      {:noreply, socket}
    end
  end

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
      confirmed_user_messages: [],
      optimistic_user_messages: [],
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
         |> assign(:form, to_form(%{"instruction" => ""}))
         |> push_event("scroll_to_bottom", %{})}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to send message")}
    end
  end

  defp append_optimistic_user_message(socket, message) do
    trimmed = String.trim(message)
    optimistic_id = "optimistic-#{System.unique_integer([:positive])}"
    updated = socket.assigns.optimistic_user_messages ++ [trimmed]
    parts = socket.assigns.output_parts ++ [{:user_pending, optimistic_id, trimmed}]

    socket
    |> assign(:optimistic_user_messages, updated)
    |> assign(:output_parts, parts)
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

    if socket.assigns.composing_new || is_nil(current_task) do
      Sessions.create_task(%{
        instruction: instruction,
        user_id: user.id,
        image: socket.assigns.selected_image
      })
    else
      Sessions.resume_task(current_task.id, %{instruction: instruction, user_id: user.id})
    end
  end

  defp handle_task_result({:ok, task}, socket) do
    user = socket.assigns.current_scope.user
    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

    is_resume = match?(%{id: id} when id == task.id, socket.assigns.current_task)

    socket =
      socket
      |> assign(:current_task, task)
      |> assign(:active_container_id, task.container_id)
      |> assign(:composing_new, false)
      |> assign(:form, to_form(%{"instruction" => ""}))

    socket =
      if is_resume do
        socket
        |> assign(:events, [])
        |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
        |> assign(:pending_question, nil)
      else
        socket
        |> assign(:events, [])
        |> assign_session_state()
      end

    {:noreply,
     socket
     |> reload_all(user.id)
     |> push_event("scroll_to_bottom", %{})
     |> push_event("focus_input", %{})}
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

  defp maybe_sync_status_from_session_event(
         socket,
         %{"type" => "session.status"} = event,
         task_id
       ) do
    status_type = get_in(event, ["properties", "status", "type"])

    case status_type do
      "idle" ->
        maybe_refresh_task_from_db(socket, task_id)

      _ ->
        socket
    end
  end

  defp maybe_sync_status_from_session_event(socket, _event, _task_id), do: socket

  defp maybe_refresh_task_from_db(socket, task_id) do
    user = socket.assigns.current_scope.user

    case Sessions.get_task(task_id, user.id) do
      {:ok, task} ->
        socket
        |> assign(:current_task, task)
        |> reload_all(user.id)

      _ ->
        socket
    end
  end

  defp reload_all(socket, user_id) do
    sessions = Sessions.list_sessions(user_id)
    tasks = Sessions.list_tasks(user_id)
    sessions = merge_unassigned_active_tasks(sessions, tasks)

    sessions =
      case {socket.assigns[:todo_items], socket.assigns[:active_container_id]} do
        {todos, cid} when is_list(todos) and todos != [] and not is_nil(cid) ->
          todo_maps =
            Enum.map(todos, fn item ->
              %{
                "id" => item[:id],
                "title" => item[:title],
                "status" => item[:status],
                "position" => item[:position]
              }
            end)

          update_session_todo_items(sessions, cid, todo_maps)

        _ ->
          sessions
      end

    socket
    |> assign(:sessions, sessions)
    |> assign(:queue_state, load_queue_state(user_id))
  end

  defp merge_unassigned_active_tasks(sessions, tasks) do
    unassigned =
      tasks
      |> Enum.filter(&(active_task?(&1) and is_nil(&1.container_id)))
      |> Enum.map(fn task ->
        %{
          container_id: "task:" <> task.id,
          task_count: 1,
          latest_status: task.status,
          latest_task_id: task.id,
          latest_error: task.error,
          title: task.instruction,
          image: task.image,
          latest_at: task.inserted_at,
          created_at: task.inserted_at,
          todo_items: task.todo_items || %{"items" => []}
        }
      end)

    # Keep newest-first ordering across real + unassigned sessions
    (sessions ++ unassigned)
    |> Enum.sort_by(& &1.latest_at, {:desc, NaiveDateTime})
  end

  defp load_queue_state(user_id) do
    Sessions.get_queue_state(user_id)
  catch
    :exit, _reason -> default_queue_state()
  end

  defp default_queue_state do
    %{
      running: 0,
      queued: [],
      awaiting_feedback: [],
      concurrency_limit: 2
    }
  end

  defp subscribe_to_active_tasks(tasks) do
    tasks
    |> Enum.filter(&active_task?/1)
    |> Enum.each(&Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{&1.id}"))
  end

  defp schedule_stats_poll do
    Process.send_after(self(), :poll_container_stats, @stats_interval_ms)
  end

  defp schedule_duration_tick do
    Process.send_after(self(), :tick_session_durations, @duration_tick_ms)
  end

  defp update_session_todo_items(sessions, container_id, todo_maps) do
    Enum.map(sessions, fn
      %{container_id: ^container_id} = session ->
        Map.put(session, :todo_items, %{"items" => todo_maps})

      session ->
        session
    end)
  end
end
