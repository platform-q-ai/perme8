defmodule Agents.Sessions.Infrastructure.TaskRunner.OutputCache do
  @moduledoc """
  Output part caching and serialization extracted from TaskRunner.

  Manages the structured `output_parts` list — a JSON-serializable array of
  maps describing text, reasoning, tool, subtask, and user message parts.
  All functions are pure — they take data arguments and return transformed
  results. The GenServer handles DB persistence and timer management.
  """

  # ---- Core part operations ----

  @doc """
  Insert or update a part by its ID.

  If a part with the same ID exists, replace it in-place. If `part_id` is nil,
  always append. Otherwise append if no match.
  """
  def upsert_part(parts, nil, entry), do: parts ++ [entry]

  def upsert_part(parts, part_id, entry) do
    case Enum.find_index(parts, fn p -> p["id"] == part_id end) do
      nil -> parts ++ [entry]
      idx -> List.replace_at(parts, idx, entry)
    end
  end

  @doc """
  JSON-encodes the output parts list.

  Returns nil for an empty list, a JSON string otherwise.
  """
  def serialize_parts([]), do: nil
  def serialize_parts(parts), do: Jason.encode!(parts)

  @doc """
  Restores output parts from the DB-persisted format.

  Handles nil, empty string, JSON arrays, and plain text strings.
  Plain text is wrapped as a single text part.
  """
  def restore_parts(nil), do: []
  def restore_parts(""), do: []

  def restore_parts(output) when is_binary(output) do
    case Jason.decode(output) do
      {:ok, parts} when is_list(parts) -> parts
      _ -> [%{"type" => "text", "id" => "cached-0", "text" => output}]
    end
  end

  def restore_parts(_), do: []

  @doc """
  Merges output into a DB attrs map.

  Prefers structured output_parts (JSON); falls back to plain output_text.
  Returns attrs unchanged if there is no output.
  """
  def put_output_attrs(attrs, output_parts, output_text) do
    case serialize_parts(output_parts) do
      nil when output_text != "" -> Map.put(attrs, :output, output_text)
      nil -> attrs
      json -> Map.put(attrs, :output, json)
    end
  end

  # ---- Subtask caching ----

  @doc """
  Builds a subtask entry map from an SSE event part.

  Returns `{entry, subtask_id}` tuple for upsert.
  """
  def build_subtask_entry(part) do
    msg_id = part["messageID"] || part["messageId"]
    subtask_id = if is_binary(msg_id), do: "subtask-#{msg_id}", else: nil

    entry = %{
      "type" => "subtask",
      "id" => subtask_id,
      "agent" => part["agent"] || "unknown",
      "description" => part["description"] || "",
      "prompt" => part["prompt"] || "",
      "status" => "running"
    }

    {entry, subtask_id}
  end

  @doc """
  Marks a subtask part as done by its part ID.

  Returns the updated output_parts list.
  """
  def mark_subtask_done(output_parts, subtask_part_id) when is_binary(subtask_part_id) do
    Enum.map(output_parts, fn
      %{"id" => ^subtask_part_id} = part -> Map.put(part, "status", "done")
      part -> part
    end)
  end

  def mark_subtask_done(output_parts, _), do: output_parts

  # ---- User message caching ----

  @doc """
  Builds a user message entry map from a text part.
  """
  def build_user_message_entry(part) do
    text = part["text"]
    msg_id = part["messageID"] || part["messageId"] || part["id"]
    part_id = if is_binary(msg_id), do: "user-" <> msg_id, else: nil
    {%{"type" => "user", "id" => part_id, "text" => text}, part_id}
  end

  @doc """
  Builds a queued (pending) user message entry.

  Returns `{entry, pending_id}` or `nil` if the message is blank.
  """
  def build_queued_user_entry(message, command_payload \\ %{})

  def build_queued_user_entry(message, command_payload) when is_binary(message) do
    text = String.trim(message)

    if text == "" do
      nil
    else
      correlation_key = Map.get(command_payload, "correlation_key")

      pending_id =
        if is_binary(correlation_key) and correlation_key != "" do
          "queued-user-#{correlation_key}"
        else
          "queued-user-#{System.unique_integer([:positive])}"
        end

      entry =
        %{"type" => "user", "id" => pending_id, "text" => text, "pending" => true}
        |> maybe_put_payload_field("correlation_key", Map.get(command_payload, "correlation_key"))
        |> maybe_put_payload_field("command_type", Map.get(command_payload, "command_type"))
        |> maybe_put_payload_field("sent_at", Map.get(command_payload, "sent_at"))

      {entry, pending_id}
    end
  end

  def build_queued_user_entry(_message, _command_payload), do: nil

  @doc """
  Replaces a pending user message with a confirmed one if the text matches.

  Returns `{updated_parts, matched?}` tuple.
  """
  def promote_pending_user_part(parts, text, part_id) do
    case Enum.find_index(parts, fn
           %{"type" => "user", "pending" => true, "text" => pending_text} ->
             String.trim(to_string(pending_text || "")) == String.trim(text)

           _ ->
             false
         end) do
      nil ->
        {parts, false}

      idx ->
        replacement = %{"type" => "user", "id" => part_id, "text" => text}
        {List.replace_at(parts, idx, replacement), true}
    end
  end

  # Conditionally adds a field to an entry map if the value is non-nil
  # and non-empty-string. Used internally by build_queued_user_entry/2.
  defp maybe_put_payload_field(entry, _key, nil), do: entry
  defp maybe_put_payload_field(entry, _key, ""), do: entry
  defp maybe_put_payload_field(entry, key, value), do: Map.put(entry, key, value)

  # ---- Answer caching ----

  @doc """
  Builds an answer entry from a question answer.

  Returns `{entry, part_id}` or `nil` if the answer text is blank.
  """
  def build_answer_entry(request_id, message, answers) do
    text =
      case message do
        msg when is_binary(msg) -> String.trim(msg)
        _ -> format_answers_for_cache(answers)
      end

    if String.trim(text) == "" do
      nil
    else
      part_id = "user-answer-#{request_id}"
      {%{"type" => "user", "id" => part_id, "text" => text}, part_id}
    end
  end

  @doc """
  Formats a list of answer groups as display text.
  """
  def format_answers_for_cache(answers) when is_list(answers) do
    answers
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {answer_list, idx} ->
      cleaned = Enum.reject(answer_list, &(&1 in [nil, ""]))
      if cleaned == [], do: nil, else: "Answer #{idx}: #{Enum.join(cleaned, ", ")}"
    end)
    |> String.trim()
  end

  def format_answers_for_cache(_), do: ""

  # ---- Tool entry building ----

  @doc """
  Builds a tool entry by merging SDK event data with existing tool state.
  """
  def build_tool_entry(part, tool_state, existing) do
    Map.merge(existing, %{
      "type" => "tool",
      "id" => part["id"],
      "name" => part["tool"] || part["name"] || "tool",
      "status" => normalize_tool_status(tool_state["status"]),
      "input" => tool_state["input"] || existing["input"],
      "title" => tool_state["title"] || existing["title"],
      "output" => tool_state["output"] || existing["output"],
      "error" => tool_state["error"] || existing["error"]
    })
  end

  @doc """
  Normalizes tool status strings to display values.
  """
  def normalize_tool_status("completed"), do: "done"
  def normalize_tool_status("error"), do: "error"
  def normalize_tool_status(_), do: "running"

  # ---- Error serialization ----

  @doc """
  Serializes an error value to a string for DB persistence.
  """
  def serialize_error(error) when is_binary(error), do: error

  def serialize_error(%{"data" => %{"message" => msg}}), do: msg
  def serialize_error(%{"message" => msg}), do: msg

  def serialize_error(error) when is_map(error) do
    case Jason.encode(error) do
      {:ok, json} -> json
      _ -> inspect(error)
    end
  end

  def serialize_error(error), do: inspect(error)
end
