defmodule AgentsWeb.SessionsLive.EventProcessor do
  @moduledoc """
  Processes task events and manages output state for the Sessions LiveView.

  Handles the event stream from running tasks (text output, tool calls,
  reasoning, questions, todo progress) and transforms socket assigns
  accordingly. Also provides cached output decoding, streaming state
  management, and todo restoration on reconnect.
  """

  import Phoenix.Component, only: [assign: 3]

  alias Agents.Sessions.Domain.Entities.{TodoItem, TodoList}

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
  # Also clean up any matching queued message when the user message
  # is processed by opencode (content match).
  def process_event(
        %{
          "type" => "message.updated",
          "properties" => %{"info" => %{"role" => "user"} = info}
        },
        socket
      ) do
    content = extract_user_message_content(info)

    socket =
      case info["id"] || info["messageID"] || info["messageId"] do
        msg_id when is_binary(msg_id) ->
          ids = MapSet.put(socket.assigns.user_message_ids, msg_id)
          assign(socket, :user_message_ids, ids)

        _ ->
          socket
      end

    remove_matching_queued_message(socket, content)
  end

  # Text output — keyed by part ID so multiple messages accumulate
  def process_event(
        %{
          "type" => "message.part.updated",
          "properties" => %{"part" => %{"type" => "text", "text" => text} = part}
        },
        socket
      )
      when text != "" do
    if user_message_part?(part, socket) do
      append_confirmed_user_message(socket, part, text)
    else
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
    handle_tool_event(socket, part["id"], part["name"] || "tool", :running, detail)
  end

  def process_event(
        %{
          "type" => "message.part.updated",
          "properties" => %{"part" => %{"type" => "tool-result"} = part}
        },
        socket
      ) do
    handle_tool_event(socket, part["id"], part["name"] || "tool", :done, %{})
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

  def process_event(_event, socket), do: socket

  @doc """
  Loads cached output from a completed task's stored output string.

  Returns the updated socket with decoded output_parts.
  """
  def maybe_load_cached_output(socket, %{output: output})
      when is_binary(output) and output != "" do
    {parts, user_messages} = decode_cached_output_with_user_messages(output)

    socket
    |> assign(:output_parts, parts)
    |> assign(:confirmed_user_messages, user_messages)
  end

  def maybe_load_cached_output(socket, _task), do: socket

  @doc """
  Restores a pending question from DB on LiveView mount/reconnect.

  Primary path: read from the persisted pending_question column.
  """
  def maybe_load_pending_question(socket, %{
        pending_question: %{"request_id" => request_id, "questions" => questions} = pq
      })
      when is_binary(request_id) and is_list(questions) and questions != [] do
    rejected = pq["rejected"] || false
    restore_question_card(socket, questions, pq["session_id"], request_id, rejected)
  end

  # Fallback path: extract question data from cached output parts.
  # Handles tasks created before the pending_question column existed,
  # where the question data only lives in the tool output.
  def maybe_load_pending_question(socket, _task) do
    case extract_question_from_output_parts(socket.assigns.output_parts) do
      {:ok, questions} ->
        restore_question_card(socket, questions, nil, nil, true)

      :none ->
        socket
    end
  end

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

  defp decode_cached_output_with_user_messages(output) do
    case Jason.decode(output) do
      {:ok, parts} when is_list(parts) ->
        {user_parts, non_user_parts} = Enum.split_with(parts, &(&1["type"] == "user"))

        decoded_parts =
          non_user_parts |> Enum.map(&decode_output_part/1) |> Enum.reject(&is_nil/1)

        user_messages =
          user_parts
          |> Enum.map(fn part ->
            text = String.trim(part["text"] || "")
            id = part["id"] || "user-part-#{System.unique_integer([:positive])}"
            %{id: id, text: text}
          end)
          |> Enum.reject(&(&1.text == ""))

        {decoded_parts, user_messages}

      _ ->
        {decode_cached_output(output), []}
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

  # Check if a part belongs to a user message (should be filtered from output)
  defp user_message_part?(%{"messageID" => msg_id}, socket) when is_binary(msg_id) do
    MapSet.member?(socket.assigns.user_message_ids, msg_id)
  end

  defp user_message_part?(%{"messageId" => msg_id}, socket) when is_binary(msg_id) do
    MapSet.member?(socket.assigns.user_message_ids, msg_id)
  end

  defp user_message_part?(_part, _socket), do: false

  defp append_confirmed_user_message(socket, part, text) do
    message_id =
      part["messageID"] || part["messageId"] || part["id"] ||
        "user-part-#{System.unique_integer([:positive])}"

    trimmed = String.trim(text)

    confirmed =
      socket.assigns
      |> Map.get(:confirmed_user_messages, [])
      |> upsert_confirmed_user_message(message_id, trimmed)

    optimistic =
      socket.assigns
      |> Map.get(:optimistic_user_messages, [])
      |> drop_first_matching_optimistic(trimmed)

    socket
    |> assign(:confirmed_user_messages, confirmed)
    |> assign(:optimistic_user_messages, optimistic)
  end

  defp upsert_confirmed_user_message(messages, id, text) do
    case Enum.find_index(messages, &(&1.id == id)) do
      nil -> messages ++ [%{id: id, text: text}]
      idx -> List.replace_at(messages, idx, %{id: id, text: text})
    end
  end

  defp drop_first_matching_optimistic(messages, text) do
    case Enum.find_index(messages, &(String.trim(&1) == text)) do
      nil -> messages
      idx -> List.delete_at(messages, idx)
    end
  end

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

  defp format_model(%{"modelID" => model_id}), do: model_id
  defp format_model(_), do: nil

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

  # Scan output parts for a question tool call and extract the questions
  # from its input. The tool name is "mcp_question" or "questions".
  defp extract_question_from_output_parts(parts) do
    Enum.find_value(parts, :none, fn
      {:tool, _id, name, _status, detail} when is_map(detail) ->
        if question_tool?(name), do: extract_questions_from_detail(detail)

      _ ->
        nil
    end)
  end

  defp extract_questions_from_detail(%{input: input}) when is_map(input) do
    case input do
      %{"questions" => questions} when is_list(questions) and questions != [] ->
        {:ok, questions}

      _ ->
        nil
    end
  end

  defp extract_questions_from_detail(%{input: input}) when is_binary(input) do
    case Jason.decode(input) do
      {:ok, %{"questions" => questions}} when is_list(questions) and questions != [] ->
        {:ok, questions}

      _ ->
        nil
    end
  end

  defp extract_questions_from_detail(_), do: nil

  defp question_tool?(name) when is_binary(name) do
    name in ["mcp_question", "questions"]
  end

  defp question_tool?(_), do: false

  # Extract text content from a user message event for queued message matching.
  defp extract_user_message_content(%{"content" => content}) when is_binary(content), do: content

  defp extract_user_message_content(%{"parts" => [%{"text" => text} | _]})
       when is_binary(text),
       do: text

  defp extract_user_message_content(_), do: nil

  # Remove the first queued message whose content matches the given text.
  defp remove_matching_queued_message(socket, nil), do: socket

  defp remove_matching_queued_message(socket, content) do
    queued = Map.get(socket.assigns, :queued_messages, [])
    if queued == [], do: socket, else: do_remove_matching(socket, queued, String.trim(content))
  end

  defp do_remove_matching(socket, queued, trimmed) do
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

  defp decode_output_part(
         %{"type" => "tool", "id" => id, "name" => name, "status" => status} = entry
       ) do
    detail = %{
      input: entry["input"],
      title: entry["title"],
      output: entry["output"],
      error: entry["error"]
    }

    {:tool, id, name, safe_tool_status(status), detail}
  end

  # Legacy format without id
  defp decode_output_part(%{"type" => "tool", "name" => name, "status" => status}) do
    {:tool, nil, name, safe_tool_status(status),
     %{input: nil, title: nil, output: nil, error: nil}}
  end

  defp decode_output_part(_), do: nil

  defp safe_tool_status("running"), do: :running
  defp safe_tool_status("done"), do: :done
  defp safe_tool_status("error"), do: :error
  defp safe_tool_status(_), do: :done
end
