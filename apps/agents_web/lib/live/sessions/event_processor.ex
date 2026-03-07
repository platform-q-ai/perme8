defmodule AgentsWeb.SessionsLive.EventProcessor do
  @moduledoc """
  Processes task events and manages output state for the Sessions LiveView.

  Handles the event stream from running tasks (text output, tool calls,
  reasoning, questions, todo progress) and transforms socket assigns
  accordingly. Also provides cached output decoding, streaming state
  management, and todo restoration on reconnect.
  """

  import Phoenix.Component, only: [assign: 3]

  require Logger

  alias Agents.Sessions.Domain.Entities.{TodoItem, TodoList}
  alias AgentsWeb.SessionsLive.SdkFieldResolver

  # ---- Public API ----

  @doc """
  Processes a single task event and returns the updated socket.

  Handles all event types: session.updated, message.updated,
  message.part.updated (text/reasoning/tool variants), question.asked,
  question.replied, question.rejected, todo.updated.
  """
  def process_event(%{"type" => "session.updated", "properties" => %{"info" => info}}, socket) do
    socket
    |> maybe_assign(:session_title, info["title"])
    |> maybe_assign(:session_summary, info["summary"])
  end

  def process_event(
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

  # Track user message IDs so we can skip their parts in output.
  # Skip tracking for subtask messages — their messageIDs are already
  # tracked in subtask_message_ids and should not appear as user messages.
  # Also clean up any matching queued message — correlation_key first,
  # content match as fallback for backward compatibility.
  def process_event(
        %{
          "type" => "message.updated",
          "properties" => %{"info" => %{"role" => "user"} = info}
        },
        socket
      ) do
    msg_id = SdkFieldResolver.resolve_message_id(info)

    if is_binary(msg_id) and
         MapSet.member?(socket.assigns.subtask_message_ids, msg_id) do
      socket
    else
      content = extract_user_message_content(info)
      correlation_key = SdkFieldResolver.resolve_correlation_key(info)

      socket =
        case msg_id do
          id when is_binary(id) ->
            ids = MapSet.put(socket.assigns.user_message_ids, id)
            assign(socket, :user_message_ids, ids)

          _ ->
            socket
        end

      dedup_queued_message(socket, correlation_key, content)
    end
  end

  # Subtask/subagent invocation — render as a forked conversation card
  # instead of a user message. Track the messageID so subsequent text
  # parts for this message are suppressed.
  def process_event(
        %{
          "type" => "message.part.updated",
          "properties" => %{"part" => %{"type" => "subtask"} = part}
        },
        socket
      ) do
    msg_id = part["messageID"] || part["messageId"]

    socket =
      if is_binary(msg_id) do
        ids = MapSet.put(socket.assigns.subtask_message_ids, msg_id)
        assign(socket, :subtask_message_ids, ids)
      else
        socket
      end

    subtask_id = if is_binary(msg_id), do: "subtask-#{msg_id}", else: "subtask-#{part["id"]}"

    detail = %{
      agent: part["agent"] || "unknown",
      description: part["description"] || "",
      prompt: part["prompt"] || "",
      status: :running
    }

    parts = upsert_part(socket.assigns.output_parts, {:subtask, subtask_id, detail})
    assign(socket, :output_parts, parts)
  end

  # Text output — keyed by part ID so multiple messages accumulate.
  # Suppress text parts that belong to subtask messages (the prompt
  # is already shown inside the subtask fork card).
  def process_event(
        %{
          "type" => "message.part.updated",
          "properties" => %{"part" => %{"type" => "text", "text" => text} = part}
        },
        socket
      )
      when text != "" do
    cond do
      subtask_message_part?(part, socket) ->
        socket

      user_message_part?(part, socket) ->
        append_confirmed_user_message(socket, part, text)

      true ->
        part_id = part["id"] || "text-default"
        parts = upsert_part(socket.assigns.output_parts, {:text, part_id, text, :streaming})
        assign(socket, :output_parts, parts)
    end
  end

  # Reasoning/thinking content — keyed by part ID
  def process_event(
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
  def process_event(
        %{
          "type" => "message.part.updated",
          "properties" => %{"part" => %{"type" => "tool-start"} = part}
        },
        socket
      ) do
    detail = %{input: part["input"] || part["args"], title: nil, output: nil, error: nil}

    tool_name = part["name"] || "tool"
    tool_id = stable_tool_part_id(part, tool_name)
    handle_tool_event(socket, tool_id, tool_name, :running, detail)
  end

  def process_event(
        %{
          "type" => "message.part.updated",
          "properties" => %{"part" => %{"type" => "tool-result"} = part}
        },
        socket
      ) do
    tool_name = part["name"] || "tool"
    tool_id = stable_tool_part_id(part, tool_name)
    handle_tool_event(socket, tool_id, tool_name, :done, %{})
  end

  # SDK-style tool part with state object — the rich format
  def process_event(
        %{
          "type" => "message.part.updated",
          "properties" => %{
            "part" => %{"type" => "tool", "state" => %{"status" => status} = state} = part
          }
        },
        socket
      ) do
    if ignore_empty_running_tool_part?(part, state, status) do
      socket
    else
      tool_name = part["tool"] || part["name"] || "tool"
      tool_id = stable_tool_part_id(part, tool_name)

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
  end

  # Question from the AI assistant — show options to user.
  # Ignore empty/malformed questions (auto-rejected by TaskRunner).
  def process_event(
        %{"type" => "question.asked", "properties" => %{"questions" => questions} = properties},
        socket
      )
      when is_list(questions) and questions != [] do
    request_id = properties["id"]

    # Initialize selected answers — one empty list per question
    initial_selections = Enum.map(questions, fn _q -> [] end)

    pending = %{
      request_id: request_id,
      session_id: properties["sessionID"],
      questions: questions,
      selected: initial_selections,
      custom_text: Enum.map(questions, fn _q -> "" end),
      rejected: false
    }

    assign(socket, :pending_question, pending)
  end

  # Question answered — clear the pending question
  def process_event(%{"type" => "question.replied"}, socket) do
    assign(socket, :pending_question, nil)
  end

  # Question rejected — keep the card visible so the user can still
  # submit an answer (which will be sent as a follow-up message)
  def process_event(%{"type" => "question.rejected"}, socket) do
    case socket.assigns.pending_question do
      nil -> socket
      pending -> assign(socket, :pending_question, %{pending | rejected: true})
    end
  end

  # The "todo.updated" event is handled via the dedicated {:todo_updated, ...}
  # PubSub message from TaskRunner, which carries pre-parsed items. Skipping
  # here avoids double processing since the generic {:task_event, ...} broadcast
  # also delivers this event.
  def process_event(%{"type" => "todo.updated"}, socket), do: socket

  def process_event(%{"type" => type} = _event, socket) do
    Logger.warning("EventProcessor: unhandled event type=#{inspect(type)}")
    socket
  end

  def process_event(_event, socket), do: socket

  @doc """
  Loads cached output from a completed task's stored output string.

  Returns the updated socket with decoded output_parts.
  """
  def maybe_load_cached_output(socket, %{output: output})
      when is_binary(output) and output != "" do
    parts = decode_cached_output(output)
    assign(socket, :output_parts, parts)
  end

  def maybe_load_cached_output(socket, _task), do: socket

  @doc """
  Restores a pending question from DB on LiveView mount/reconnect.

  Primary path: read from the persisted pending_question column.
  """
  # Skip loading pending questions for terminal tasks — the question is no
  # longer actionable once the session has ended.
  def maybe_load_pending_question(socket, %{status: status})
      when status in ["completed", "failed", "cancelled"],
      do: socket

  def maybe_load_pending_question(socket, %{
        pending_question: %{"request_id" => request_id, "questions" => questions} = pq
      })
      when is_binary(request_id) and is_list(questions) and questions != [] do
    rejected = pq["rejected"] || false
    restore_question_card(socket, questions, pq["session_id"], request_id, rejected)
  end

  # Do not restore from cached tool output. Only persisted pending_question
  # should control question-card visibility to avoid resurrecting stale prompts.
  def maybe_load_pending_question(socket, _task), do: socket

  @doc """
  Restores todo items from persisted task state on LiveView mount/reconnect.
  """
  def maybe_load_todos(socket, %{todo_items: %{"items" => items}}) when is_list(items) do
    todo_list = TodoList.from_maps(items)
    assign(socket, :todo_items, todo_items_for_assigns(todo_list))
  end

  def maybe_load_todos(socket, _task), do: socket

  @doc """
  Returns true if any parts are currently streaming (text/reasoning) or running (tool).
  """
  def has_streaming_parts?(parts) do
    Enum.any?(parts, fn
      {:text, _, _, :streaming} -> true
      {:reasoning, _, _, :streaming} -> true
      {:tool, _, _, :running, _} -> true
      {:subtask, _, %{status: :running}} -> true
      _ -> false
    end)
  end

  @doc """
  Freezes all streaming text/reasoning segments (switch to markdown rendering).
  """
  def freeze_streaming(parts) do
    Enum.map(parts, fn
      {:text, id, text, :streaming} -> {:text, id, text, :frozen}
      {:reasoning, id, text, :streaming} -> {:reasoning, id, text, :frozen}
      {:tool, id, name, :running, detail} -> {:tool, id, name, :done, detail}
      {:subtask, id, %{status: :running} = detail} -> {:subtask, id, %{detail | status: :done}}
      other -> other
    end)
  end

  @doc """
  Decodes a cached output string (JSON or plain text) into output part tuples.
  """
  def decode_cached_output(output) do
    case Jason.decode(output) do
      {:ok, parts} when is_list(parts) ->
        parts |> Enum.map(&decode_output_part/1) |> Enum.reject(&is_nil/1)

      _ ->
        [{:text, "cached-0", output, :frozen}]
    end
  end

  # ---- Private helpers ----

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

  # Check if a part belongs to a subtask message (should be suppressed from output)
  defp subtask_message_part?(part, socket) do
    case part["messageID"] || part["messageId"] do
      msg_id when is_binary(msg_id) ->
        MapSet.member?(socket.assigns.subtask_message_ids, msg_id)

      _ ->
        false
    end
  end

  # Check if a part belongs to a user message (should be filtered from output)
  defp user_message_part?(part, socket) do
    case part["messageID"] || part["messageId"] do
      msg_id when is_binary(msg_id) ->
        MapSet.member?(socket.assigns.user_message_ids, msg_id)

      _ ->
        false
    end
  end

  defp append_confirmed_user_message(socket, part, text) do
    message_id =
      SdkFieldResolver.resolve_message_id(part) ||
        "user-part-#{System.unique_integer([:positive])}"

    trimmed = String.trim(text)

    {parts, matched?} =
      promote_pending_user_part(socket.assigns.output_parts, trimmed, message_id)

    parts =
      if matched? do
        parts
      else
        upsert_part(parts, {:user, message_id, trimmed})
      end

    optimistic =
      drop_first_matching_optimistic(
        Map.get(socket.assigns, :optimistic_user_messages, []),
        trimmed
      )

    socket
    |> assign(:output_parts, parts)
    |> assign(:optimistic_user_messages, optimistic)
  end

  defp promote_pending_user_part(parts, text, message_id) do
    case Enum.find_index(parts, fn
           {:user_pending, _id, pending_text} -> String.trim(pending_text) == text
           _ -> false
         end) do
      nil -> {parts, false}
      idx -> {List.replace_at(parts, idx, {:user, message_id, text}), true}
    end
  end

  defp drop_first_matching_optimistic(messages, text) do
    case Enum.find_index(messages, &(String.trim(&1) == text)) do
      nil -> messages
      idx -> List.delete_at(messages, idx)
    end
  end

  defp stable_tool_part_id(part, tool_name) do
    SdkFieldResolver.resolve_tool_call_id(part) ||
      "tool-" <>
        Integer.to_string(
          :erlang.phash2({tool_name, part["messageID"] || part["messageId"] || ""})
        )
  end

  defp ignore_empty_running_tool_part?(part, state, status) do
    running_tool_status?(status) and
      blank_tool_identity?(part) and
      empty_tool_state?(state)
  end

  defp running_tool_status?(status), do: status in ["pending", "running"]

  defp blank_tool_identity?(part) do
    blank?(part["tool"]) and
      blank?(part["name"]) and
      blank?(part["id"]) and
      blank?(part["toolCallID"]) and
      blank?(part["toolCallId"]) and
      blank?(part["callID"])
  end

  defp empty_tool_state?(state) do
    is_nil(state["input"]) and
      is_nil(state["title"]) and
      is_nil(state["output"]) and
      is_nil(state["error"])
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false

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

  defp format_model(info), do: SdkFieldResolver.resolve_model_id(info)

  defp restore_question_card(socket, questions, session_id, request_id, rejected) do
    initial_selections = Enum.map(questions, fn _q -> [] end)

    pending = %{
      request_id: request_id,
      session_id: session_id,
      questions: questions,
      selected: initial_selections,
      custom_text: Enum.map(questions, fn _q -> "" end),
      rejected: rejected
    }

    assign(socket, :pending_question, pending)
  end

  # Extract text content from a user message event for queued message matching.
  defp extract_user_message_content(%{"content" => content}) when is_binary(content), do: content

  defp extract_user_message_content(%{"parts" => [%{"text" => text} | _]})
       when is_binary(text),
       do: text

  defp extract_user_message_content(_), do: nil

  # Dedup a queued message: try correlation_key match first, then content fallback.
  defp dedup_queued_message(socket, correlation_key, content) do
    queued = Map.get(socket.assigns, :queued_messages, [])
    if queued == [], do: socket, else: do_dedup_queued(socket, queued, correlation_key, content)
  end

  defp do_dedup_queued(socket, queued, correlation_key, content) do
    case remove_by_correlation_key(queued, correlation_key) do
      {:ok, updated} ->
        assign(socket, :queued_messages, updated)

      :no_match ->
        # Fall back to content-based matching for backward compatibility
        remove_matching_queued_message_by_content(socket, queued, content)
    end
  end

  defp remove_by_correlation_key(_queued, nil), do: :no_match

  defp remove_by_correlation_key(queued, correlation_key) do
    case Enum.find_index(queued, fn msg ->
           Map.get(msg, :correlation_key) == correlation_key
         end) do
      nil -> :no_match
      idx -> {:ok, List.delete_at(queued, idx)}
    end
  end

  # Remove the first queued message whose content matches the given text.
  defp remove_matching_queued_message_by_content(socket, _queued, nil), do: socket

  defp remove_matching_queued_message_by_content(socket, queued, content) do
    trimmed = String.trim(content)

    case Enum.find_index(queued, fn msg -> String.trim(msg.content) == trimmed end) do
      nil -> socket
      idx -> assign(socket, :queued_messages, List.delete_at(queued, idx))
    end
  end

  @doc """
  Converts a TodoList aggregate into the plain-map format used by LiveView assigns.

  Each item becomes a map with atom keys suitable for template rendering.
  """
  def todo_items_for_assigns(%TodoList{items: items}) do
    Enum.map(items, fn %TodoItem{} = item ->
      %{id: item.id, title: item.title, status: item.status, position: item.position}
    end)
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

  defp decode_output_part(%{"type" => "user", "id" => id, "text" => text, "pending" => true}) do
    {:user_pending, id, text}
  end

  defp decode_output_part(%{"type" => "user", "id" => id, "text" => text}) do
    {:user, id, text}
  end

  defp decode_output_part(
         %{"type" => "tool", "id" => id, "name" => name, "status" => status} = entry
       ) do
    if ignore_empty_cached_tool?(name, entry) do
      nil
    else
      detail = %{
        input: entry["input"],
        title: entry["title"],
        output: entry["output"],
        error: entry["error"]
      }

      {:tool, id, name, safe_cached_tool_status(status), detail}
    end
  end

  defp decode_output_part(%{"type" => "subtask", "id" => id, "agent" => agent} = entry) do
    {:subtask, id,
     %{
       agent: agent,
       description: entry["description"] || "",
       prompt: entry["prompt"] || "",
       status: :done
     }}
  end

  # Legacy format without id
  defp decode_output_part(%{"type" => "tool", "name" => name, "status" => status}) do
    if ignore_empty_cached_tool?(name, %{}) do
      nil
    else
      synthetic_id = "tool-" <> Integer.to_string(:erlang.phash2({name, status}))

      {:tool, synthetic_id, name, safe_cached_tool_status(status),
       %{input: nil, title: nil, output: nil, error: nil}}
    end
  end

  defp decode_output_part(_), do: nil

  defp safe_tool_status("running"), do: :running
  defp safe_tool_status("done"), do: :done
  defp safe_tool_status("error"), do: :error
  defp safe_tool_status(_), do: :done

  # Cached output is a snapshot and may contain stale running states if
  # the stream disconnected. Render cached tools as terminal by default.
  defp safe_cached_tool_status("running"), do: :done
  defp safe_cached_tool_status("pending"), do: :done
  defp safe_cached_tool_status(status), do: safe_tool_status(status)

  defp ignore_empty_cached_tool?(name, entry) do
    blank?(name) and is_nil(entry["input"]) and is_nil(entry["title"]) and is_nil(entry["output"]) and
      is_nil(entry["error"])
  end
end
