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
     |> assign(:container_stats, %{})
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
        question = Enum.at(pending.questions, q_idx)
        multiple = question["multiple"] || false
        current = Enum.at(pending.selected, q_idx, [])

        new_selection =
          if multiple do
            if label in current, do: List.delete(current, label), else: current ++ [label]
          else
            if label in current, do: [], else: [label]
          end

        updated_selected = List.replace_at(pending.selected, q_idx, new_selection)
        updated_pending = %{pending | selected: updated_selected}
        {:noreply, assign(socket, :pending_question, updated_pending)}
    end
  end

  @impl true
  def handle_event("update_question_form", %{"custom_answer" => custom_map}, socket) do
    case socket.assigns.pending_question do
      nil ->
        {:noreply, socket}

      pending ->
        # custom_map is %{"0" => "value", "1" => "value", ...}
        updated_custom =
          Enum.with_index(pending.custom_text)
          |> Enum.map(fn {_old, idx} ->
            Map.get(custom_map, to_string(idx), "")
          end)

        updated_pending = %{pending | custom_text: updated_custom}
        {:noreply, assign(socket, :pending_question, updated_pending)}
    end
  end

  @impl true
  def handle_event("update_question_form", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_question_answer", _params, socket) do
    case {socket.assigns.pending_question, socket.assigns.current_task} do
      {nil, _} ->
        {:noreply, socket}

      {pending, %{id: task_id}} ->
        # Build final answers: for each question, merge selected options + custom text
        answers =
          Enum.zip(pending.selected, pending.custom_text)
          |> Enum.map(fn {selected, custom} ->
            custom_trimmed = String.trim(custom)

            if custom_trimmed != "" do
              selected ++ [custom_trimmed]
            else
              selected
            end
          end)

        Sessions.answer_question(task_id, pending.request_id, answers)
        {:noreply, assign(socket, :pending_question, nil)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("dismiss_question", _params, socket) do
    case {socket.assigns.pending_question, socket.assigns.current_task} do
      {nil, _} ->
        {:noreply, socket}

      {pending, %{id: task_id}} ->
        Sessions.reject_question(task_id, pending.request_id)
        {:noreply, assign(socket, :pending_question, nil)}

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

    # Freeze streaming text and clear pending questions when task reaches a terminal state
    socket =
      if status in ["completed", "failed", "cancelled"] do
        socket
        |> assign(:output_parts, freeze_streaming(socket.assigns.output_parts))
        |> assign(:pending_question, nil)
      else
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
    # Refresh from DB to get container_id, output, etc.
    # The DB write happens before the PubSub broadcast in TaskRunner,
    # so the DB status should already be correct. Fall back to the
    # PubSub status only if the DB read fails.
    user = socket.assigns.current_scope.user

    case Sessions.get_task(task_id, user.id) do
      {:ok, refreshed} -> refreshed
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
    |> assign(:pending_question, nil)
    |> assign(:user_message_ids, MapSet.new())
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

  # Track user message IDs so we can skip their parts in output
  defp process_event(
         %{
           "type" => "message.updated",
           "properties" => %{"info" => %{"role" => "user", "id" => msg_id}}
         },
         socket
       )
       when is_binary(msg_id) do
    ids = MapSet.put(socket.assigns.user_message_ids, msg_id)
    assign(socket, :user_message_ids, ids)
  end

  # Text output — keyed by part ID so multiple messages accumulate
  defp process_event(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "text", "text" => text} = part}
         },
         socket
       )
       when text != "" do
    if user_message_part?(part, socket) do
      socket
    else
      part_id = part["id"] || "text-default"
      parts = upsert_part(socket.assigns.output_parts, {:text, part_id, text, :streaming})
      assign(socket, :output_parts, parts)
    end
  end

  # Reasoning/thinking content — keyed by part ID
  defp process_event(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "reasoning", "text" => text} = part}
         },
         socket
       )
       when is_binary(text) and text != "" do
    part_id = part["id"] || "reasoning-default"
    parts = upsert_part(socket.assigns.output_parts, {:reasoning, part_id, text, :streaming})
    assign(socket, :output_parts, parts)
  end

  # tool-start / tool-result format (legacy)
  defp process_event(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "tool-start"} = part}
         },
         socket
       ) do
    detail = %{input: part["input"] || part["args"], title: nil, output: nil, error: nil}
    handle_tool_event(socket, part["id"], part["name"] || "tool", :running, detail)
  end

  defp process_event(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "tool-result"} = part}
         },
         socket
       ) do
    handle_tool_event(socket, part["id"], part["name"] || "tool", :done, %{})
  end

  # SDK-style tool part with state object — the rich format
  defp process_event(
         %{
           "type" => "message.part.updated",
           "properties" => %{
             "part" => %{"type" => "tool", "state" => %{"status" => status} = state} = part
           }
         },
         socket
       ) do
    tool_name = part["tool"] || part["name"] || "tool"
    tool_id = part["id"]

    detail = %{
      input: state["input"],
      title: state["title"],
      output: state["output"],
      error: state["error"]
    }

    tool_status =
      case status do
        s when s in ["pending", "running"] -> :running
        "completed" -> :done
        "error" -> :error
        _ -> :running
      end

    handle_tool_event(socket, tool_id, tool_name, tool_status, detail)
  end

  # Question from the AI assistant — show options to user
  defp process_event(
         %{"type" => "question.asked", "properties" => properties},
         socket
       ) do
    request_id = properties["id"]
    questions = properties["questions"] || []

    # Initialize selected answers — one empty list per question
    initial_selections = Enum.map(questions, fn _q -> [] end)

    pending = %{
      request_id: request_id,
      session_id: properties["sessionID"],
      questions: questions,
      selected: initial_selections,
      custom_text: Enum.map(questions, fn _q -> "" end)
    }

    assign(socket, :pending_question, pending)
  end

  # Question answered — clear the pending question
  defp process_event(%{"type" => "question.replied"}, socket) do
    assign(socket, :pending_question, nil)
  end

  defp process_event(%{"type" => "question.rejected"}, socket) do
    assign(socket, :pending_question, nil)
  end

  defp process_event(_event, socket), do: socket

  defp handle_tool_event(socket, tool_id, tool_name, status, new_detail) do
    parts = freeze_streaming(socket.assigns.output_parts)

    # Merge new detail into existing detail (if tool already exists)
    existing_detail =
      case Enum.find(parts, fn p -> elem(p, 0) == :tool && elem(p, 1) == tool_id end) do
        {:tool, _, _, _, existing} when is_map(existing) -> existing
        _ -> %{input: nil, title: nil, output: nil, error: nil}
      end

    merged = Map.merge(existing_detail, new_detail, fn _k, old, new -> new || old end)
    parts = upsert_part(parts, {:tool, tool_id, tool_name, status, merged})
    assign(socket, :output_parts, parts)
  end

  # Check if a part belongs to a user message (should be filtered from output)
  defp user_message_part?(%{"messageID" => msg_id}, socket) when is_binary(msg_id) do
    MapSet.member?(socket.assigns.user_message_ids, msg_id)
  end

  defp user_message_part?(_part, _socket), do: false

  defp maybe_assign(socket, _key, nil), do: socket
  defp maybe_assign(socket, key, value), do: assign(socket, key, value)

  # Insert or update a part by its ID (second element of the tuple).
  # If a part with the same ID exists, replace it in-place. Otherwise append.
  defp upsert_part(parts, new_part) do
    new_id = elem(new_part, 1)

    case Enum.find_index(parts, fn part -> elem(part, 1) == new_id end) do
      nil -> parts ++ [new_part]
      idx -> List.replace_at(parts, idx, new_part)
    end
  end

  # Freeze all streaming text/reasoning segments (switch to markdown rendering)
  defp freeze_streaming(parts) do
    Enum.map(parts, fn
      {:text, id, text, :streaming} -> {:text, id, text, :frozen}
      {:reasoning, id, text, :streaming} -> {:reasoning, id, text, :frozen}
      other -> other
    end)
  end

  defp format_model(%{"modelID" => model_id}), do: model_id
  defp format_model(_), do: nil

  # ---- Cached output ----

  defp maybe_load_cached_output(socket, %{output: output})
       when is_binary(output) and output != "" do
    parts = decode_cached_output(output)
    assign(socket, :output_parts, parts)
  end

  defp maybe_load_cached_output(socket, _task), do: socket

  # Try JSON decode first (structured output_parts from TaskRunner).
  # Fall back to plain text for legacy records.
  defp decode_cached_output(output) do
    case Jason.decode(output) do
      {:ok, parts} when is_list(parts) ->
        parts |> Enum.map(&decode_output_part/1) |> Enum.reject(&is_nil/1)

      _ ->
        [{:text, "cached-0", output, :frozen}]
    end
  end

  defp decode_output_part(%{"type" => "text", "id" => id, "text" => text}) do
    {:text, id, text, :frozen}
  end

  # Legacy format with "segment" key
  defp decode_output_part(%{"type" => "text", "segment" => seg, "text" => text}) do
    {:text, "seg-#{seg}", text, :frozen}
  end

  defp decode_output_part(%{"type" => "reasoning", "id" => id, "text" => text}) do
    {:reasoning, id, text, :frozen}
  end

  defp decode_output_part(%{"type" => "tool", "id" => id, "name" => name, "status" => status}) do
    {:tool, id, name, String.to_existing_atom(status), nil}
  end

  # Legacy format without id
  defp decode_output_part(%{"type" => "tool", "name" => name, "status" => status}) do
    {:tool, nil, name, String.to_existing_atom(status), nil}
  end

  defp decode_output_part(_), do: nil

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

  defp schedule_stats_poll do
    Process.send_after(self(), :poll_container_stats, @stats_interval_ms)
  end

  defp poll_running_session_stats(sessions) do
    sessions
    |> Enum.filter(&(&1.latest_status in ["running", "starting", "pending"]))
    |> Enum.reduce(%{}, fn session, acc ->
      case Sessions.get_container_stats(session.container_id) do
        {:ok, stats} ->
          mem_percent =
            if stats.memory_limit > 0,
              do: Float.round(stats.memory_usage / stats.memory_limit * 100, 1),
              else: 0.0

          Map.put(acc, session.container_id, %{
            cpu_percent: stats.cpu_percent,
            memory_percent: mem_percent,
            memory_usage: stats.memory_usage,
            memory_limit: stats.memory_limit
          })

        {:error, _} ->
          acc
      end
    end)
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
            <ul class="menu menu-sm p-2 gap-1 w-full">
              <li :for={session <- @sessions} class="w-full">
                <div
                  class={[
                    "flex flex-col gap-0.5 w-full rounded-lg p-2",
                    session.container_id == @active_container_id && "active"
                  ]}
                  phx-click="select_session"
                  phx-value-container-id={session.container_id}
                >
                  <div class="flex items-center justify-between w-full">
                    <span class="text-xs font-medium truncate flex-1 min-w-0">
                      {truncate_instruction(session.title, 35)}
                    </span>
                    <.status_dot status={session.latest_status} />
                  </div>
                  <div class="flex items-center gap-2 text-[0.65rem] text-base-content/50 w-full">
                    <span>{session.task_count} task{if session.task_count != 1, do: "s"}</span>
                    <span>&middot;</span>
                    <span>{relative_time(session.latest_at)}</span>
                  </div>
                  <.container_stats_bars
                    :if={Map.has_key?(@container_stats, session.container_id)}
                    stats={@container_stats[session.container_id]}
                  />
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
            <%= if @current_task do %>
              <%!-- User message --%>
              <div class="flex gap-2 mb-3">
                <div class="shrink-0 size-6 rounded-full bg-primary/10 flex items-center justify-center">
                  <.icon name="hero-user" class="size-3.5 text-primary" />
                </div>
                <div class="flex-1 min-w-0">
                  <div class="text-xs font-medium text-base-content/50 mb-0.5">You</div>
                  <div class="text-sm whitespace-pre-line break-words">
                    {String.trim(@current_task.instruction)}
                  </div>
                </div>
              </div>
            <% end %>
            <%= if @output_parts == [] && task_running?(@current_task) do %>
              <div class="flex gap-2">
                <div class="shrink-0 size-6 rounded-full bg-secondary/10 flex items-center justify-center">
                  <.icon name="hero-cpu-chip" class="size-3.5 text-secondary" />
                </div>
                <div class="flex items-center gap-2 text-base-content/50 text-sm">
                  <span class="loading loading-dots loading-xs"></span>
                  <span>Waiting for response...</span>
                </div>
              </div>
            <% end %>
            <%= if @output_parts == [] && !task_running?(@current_task) && @current_task == nil do %>
              <div class="flex flex-col items-center justify-center h-full text-base-content/40">
                <.icon name="hero-command-line" class="size-12 mb-3" />
                <p class="text-sm">Enter an instruction below to start</p>
              </div>
            <% end %>
            <%= if @output_parts != [] do %>
              <div class="flex gap-2">
                <div class="shrink-0 size-6 rounded-full bg-secondary/10 flex items-center justify-center mt-0.5">
                  <.icon name="hero-cpu-chip" class="size-3.5 text-secondary" />
                </div>
                <div class="flex-1 min-w-0">
                  <div class="text-xs font-medium text-base-content/50 mb-0.5">Assistant</div>
                  <%= for part <- @output_parts do %>
                    <.output_part part={part} />
                  <% end %>
                </div>
              </div>
            <% end %>
            <%!-- Pending question from assistant --%>
            <.question_card
              :if={@pending_question}
              pending={@pending_question}
            />
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

  # Question card — renders the AI assistant's question with selectable options
  defp question_card(assigns) do
    ~H"""
    <div class="mt-3 rounded-lg border-2 border-warning/40 bg-warning/5 p-4">
      <div class="flex items-center gap-2 mb-3">
        <.icon name="hero-question-mark-circle" class="size-5 text-warning" />
        <span class="font-semibold text-sm text-warning">Question from Assistant</span>
      </div>

      <form id="question-form" phx-change="update_question_form" phx-submit="submit_question_answer">
        <%= for {question, q_idx} <- Enum.with_index(@pending.questions) do %>
          <div class={["mb-4", q_idx > 0 && "pt-3 border-t border-base-300/50"]}>
            <div class="text-xs font-semibold text-base-content/60 uppercase tracking-wider mb-1">
              {question["header"]}
            </div>
            <p class="text-sm mb-2">{question["question"]}</p>

            <div :if={question["multiple"]} class="text-[0.65rem] text-base-content/50 mb-1">
              Select one or more options
            </div>

            <div class="flex flex-wrap gap-1.5 mb-2">
              <%= for option <- question["options"] || [] do %>
                <% selected = option["label"] in Enum.at(@pending.selected, q_idx, []) %>
                <button
                  type="button"
                  phx-click="toggle_question_option"
                  phx-value-question-index={q_idx}
                  phx-value-label={option["label"]}
                  class={[
                    "btn btn-sm",
                    if(selected, do: "btn-primary", else: "btn-outline")
                  ]}
                  title={option["description"]}
                >
                  {option["label"]}
                </button>
              <% end %>
            </div>

            <%!-- Custom text input — always available (opencode default) --%>
            <div class="mt-2">
              <input
                type="text"
                name={"custom_answer[#{q_idx}]"}
                placeholder="Type your own answer..."
                value={Enum.at(@pending.custom_text, q_idx, "")}
                phx-debounce="300"
                class="input input-bordered input-sm w-full text-sm"
              />
            </div>
          </div>
        <% end %>

        <div class="flex gap-2 mt-2">
          <button
            type="submit"
            class="btn btn-primary btn-sm"
          >
            <.icon name="hero-check" class="size-4" /> Submit Answer
          </button>
          <button
            type="button"
            phx-click="dismiss_question"
            class="btn btn-ghost btn-sm"
          >
            Dismiss
          </button>
        </div>
      </form>
    </div>
    """
  end

  # Streaming text — render raw for speed (character-by-character feel)
  defp output_part(%{part: {:text, _id, text, :streaming}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <div class="session-markdown py-1 whitespace-pre-wrap break-words">
      {@text}<span class="inline-block w-2 h-4 bg-primary/70 animate-pulse align-text-bottom ml-0.5"></span>
    </div>
    """
  end

  # Frozen text — render as markdown (final form)
  defp output_part(%{part: {:text, _id, text, :frozen}} = assigns) do
    assigns = assign(assigns, :rendered_html, render_markdown(text))

    ~H"""
    <div class="session-markdown py-1">{@rendered_html}</div>
    """
  end

  # Streaming reasoning — render raw in a thinking block
  defp output_part(%{part: {:reasoning, _id, text, :streaming}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <div class="my-1 rounded-lg border border-base-300 bg-base-200/30 text-xs">
      <div class="flex items-center gap-1.5 px-3 py-1.5 border-b border-base-300/50">
        <span class="loading loading-dots loading-xs text-secondary"></span>
        <span class="font-medium text-secondary/80 text-[0.65rem] uppercase tracking-wider">
          Thinking
        </span>
      </div>
      <div class="px-3 py-2 whitespace-pre-wrap break-words text-base-content/60 max-h-48 overflow-y-auto">
        {@text}
      </div>
    </div>
    """
  end

  # Frozen reasoning — render as markdown in a thinking block
  defp output_part(%{part: {:reasoning, _id, text, :frozen}} = assigns) do
    assigns = assign(assigns, :rendered_html, render_markdown(text))

    ~H"""
    <details class="my-1 rounded-lg border border-base-300 bg-base-200/30 text-xs group">
      <summary class="flex items-center gap-1.5 px-3 py-1.5 cursor-pointer select-none">
        <.icon name="hero-light-bulb" class="size-3.5 text-secondary/70" />
        <span class="font-medium text-secondary/80 text-[0.65rem] uppercase tracking-wider">
          Thinking
        </span>
        <.icon
          name="hero-chevron-right"
          class="size-3 text-base-content/40 ml-auto transition-transform group-open:rotate-90"
        />
      </summary>
      <div class="px-3 py-2 border-t border-base-300/50 session-markdown text-base-content/60 max-h-64 overflow-y-auto">
        {@rendered_html}
      </div>
    </details>
    """
  end

  # Tool card — 5-tuple: {:tool, id, name, status, detail}
  # detail is a map with :title, :input, :output, :error keys
  defp output_part(%{part: {:tool, _id, name, status, detail}} = assigns)
       when is_map(detail) do
    title = detail[:title] || detail["title"]
    input = detail[:input] || detail["input"]
    output = detail[:output] || detail["output"]
    error = detail[:error] || detail["error"]

    assigns =
      assigns
      |> assign(:name, name)
      |> assign(:tool_status, status)
      |> assign(:title, title)
      |> assign(:input, input)
      |> assign(:output, output)
      |> assign(:error, error)
      |> assign(:has_detail, !!(input || output || error))

    ~H"""
    <details
      class="my-1 rounded-lg border border-base-300 bg-base-200/40 text-xs group"
      open={@tool_status == :running}
    >
      <summary class="flex items-center gap-2 px-3 py-1.5 cursor-pointer select-none">
        <span :if={@tool_status == :running} class="loading loading-spinner loading-xs text-info">
        </span>
        <.icon :if={@tool_status == :done} name="hero-check-circle" class="size-3.5 text-success" />
        <.icon
          :if={@tool_status == :error}
          name="hero-exclamation-circle"
          class="size-3.5 text-error"
        />
        <span class="font-medium text-base-content/80">
          <.tool_icon name={@name} /> {@name}
        </span>
        <span :if={@title} class="text-base-content/50 truncate flex-1">{@title}</span>
        <.icon
          :if={@has_detail}
          name="hero-chevron-right"
          class="size-3 text-base-content/30 ml-auto transition-transform group-open:rotate-90 shrink-0"
        />
      </summary>
      <div :if={@has_detail} class="border-t border-base-300/50">
        <div :if={@input} class="px-3 py-1.5">
          <div class="text-[0.6rem] font-semibold text-base-content/40 uppercase tracking-wider mb-0.5">
            Input
          </div>
          <pre class="text-[0.65rem] leading-snug text-base-content/60 whitespace-pre-wrap break-all max-h-32 overflow-y-auto"><code>{format_tool_input(@input)}</code></pre>
        </div>
        <div :if={@output} class={["px-3 py-1.5", @input && "border-t border-base-300/30"]}>
          <div class="text-[0.6rem] font-semibold text-base-content/40 uppercase tracking-wider mb-0.5">
            Output
          </div>
          <pre class="text-[0.65rem] leading-snug text-base-content/60 whitespace-pre-wrap break-all max-h-32 overflow-y-auto"><code>{truncate_output(@output)}</code></pre>
        </div>
        <div
          :if={@error}
          class={["px-3 py-1.5", (@input || @output) && "border-t border-base-300/30"]}
        >
          <div class="text-[0.6rem] font-semibold text-error/70 uppercase tracking-wider mb-0.5">
            Error
          </div>
          <pre class="text-[0.65rem] leading-snug text-error/80 whitespace-pre-wrap break-all max-h-32 overflow-y-auto"><code>{@error}</code></pre>
        </div>
      </div>
    </details>
    """
  end

  # Tool with non-map detail (legacy plain input value)
  defp output_part(%{part: {:tool, id, name, status, input}} = assigns)
       when not is_map(input) do
    detail = %{input: input, title: nil, output: nil, error: nil}
    assigns = Map.put(assigns, :part, {:tool, id, name, status, detail})
    output_part(assigns)
  end

  # Legacy 4-tuple tool compat {:tool, name, status, input}
  defp output_part(%{part: {:tool, name, status, input}} = assigns)
       when is_atom(status) do
    detail =
      if is_map(input), do: input, else: %{input: input, title: nil, output: nil, error: nil}

    assigns = Map.put(assigns, :part, {:tool, nil, name, status, detail})
    output_part(assigns)
  end

  # Legacy 3-tuple tool compat {:tool, name, status}
  defp output_part(%{part: {:tool, name, status}} = assigns)
       when is_atom(status) do
    assigns =
      Map.put(
        assigns,
        :part,
        {:tool, nil, name, status, %{input: nil, title: nil, output: nil, error: nil}}
      )

    output_part(assigns)
  end

  defp output_part(assigns) do
    ~H"""
    """
  end

  defp tool_icon(%{name: name} = assigns) do
    assigns = assign(assigns, :icon_name, tool_icon_name(name))

    ~H"""
    <.icon name={@icon_name} class="size-3 inline-block" />
    """
  end

  defp tool_icon_name("bash"), do: "hero-command-line"
  defp tool_icon_name("read"), do: "hero-document-text"
  defp tool_icon_name("write"), do: "hero-pencil-square"
  defp tool_icon_name("edit"), do: "hero-pencil"
  defp tool_icon_name("glob"), do: "hero-folder-open"
  defp tool_icon_name("grep"), do: "hero-magnifying-glass"
  defp tool_icon_name("list"), do: "hero-list-bullet"
  defp tool_icon_name(_), do: "hero-wrench-screwdriver"

  defp format_tool_input(nil), do: ""
  defp format_tool_input(input) when is_binary(input), do: input
  defp format_tool_input(input) when is_map(input), do: Jason.encode!(input, pretty: true)
  defp format_tool_input(input), do: inspect(input)

  defp truncate_output(nil), do: ""

  defp truncate_output(text) when is_binary(text) and byte_size(text) > 2000 do
    String.slice(text, 0, 2000) <> "\n... (truncated)"
  end

  defp truncate_output(text) when is_binary(text), do: text
  defp truncate_output(other), do: inspect(other)

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

  defp container_stats_bars(assigns) do
    ~H"""
    <div class="flex flex-col gap-0.5 w-full mt-1">
      <div class="flex items-center gap-1.5">
        <span class="text-[0.6rem] text-base-content/40 w-7 shrink-0">CPU</span>
        <div class="flex-1 bg-base-300 rounded-full h-1.5 overflow-hidden">
          <div
            class="bg-info h-full rounded-full transition-all duration-500"
            style={"width: #{min(@stats.cpu_percent, 100)}%"}
          >
          </div>
        </div>
        <span class="text-[0.6rem] text-base-content/40 w-8 text-right shrink-0">
          {Float.round(@stats.cpu_percent, 0) |> trunc()}%
        </span>
      </div>
      <div class="flex items-center gap-1.5">
        <span class="text-[0.6rem] text-base-content/40 w-7 shrink-0">MEM</span>
        <div class="flex-1 bg-base-300 rounded-full h-1.5 overflow-hidden">
          <div
            class={[
              "h-full rounded-full transition-all duration-500",
              if(@stats.memory_percent >= 90, do: "bg-error", else: "bg-success")
            ]}
            style={"width: #{min(@stats.memory_percent, 100)}%"}
          >
          </div>
        </div>
        <span class="text-[0.6rem] text-base-content/40 w-8 text-right shrink-0">
          {format_mem_short(@stats.memory_usage)}
        </span>
      </div>
    </div>
    """
  end

  defp format_mem_short(bytes) when bytes >= 1_073_741_824 do
    "#{Float.round(bytes / 1_073_741_824, 1)}G"
  end

  defp format_mem_short(bytes) when bytes >= 1_048_576 do
    "#{Float.round(bytes / 1_048_576, 0) |> trunc()}M"
  end

  defp format_mem_short(bytes) when bytes >= 1024 do
    "#{Float.round(bytes / 1024, 0) |> trunc()}K"
  end

  defp format_mem_short(_bytes), do: "0"
end
