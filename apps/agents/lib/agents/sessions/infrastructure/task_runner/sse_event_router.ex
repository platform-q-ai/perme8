defmodule Agents.Sessions.Infrastructure.TaskRunner.SseEventRouter do
  @moduledoc """
  SSE event routing and session tracking extracted from TaskRunner.

  Contains pure functions for extracting session IDs from events, tracking
  subtask/user message IDs, and checking if events are subtask or user
  message parts. The actual event dispatch (handle_sdk_event) and process
  management remain in TaskRunner.
  """

  @doc """
  Extracts the session ID from an SSE event's properties.

  Checks `sessionID`, `session_id`, and nested `part.sessionID`/`part.session_id`.
  Returns nil if no session ID is found.
  """
  def extract_session_id(%{"properties" => props}) when is_map(props) do
    props["sessionID"] || props["session_id"] || get_in(props, ["part", "sessionID"]) ||
      get_in(props, ["part", "session_id"])
  end

  def extract_session_id(_), do: nil

  @doc """
  Tracks a subtask message ID from a subtask part event.

  Adds the message ID to `subtask_message_ids` and registers the child
  session ID in `child_session_ids` for child event routing.

  Returns `{updated_subtask_message_ids, updated_child_session_ids}`.
  """
  def track_subtask_message_id(
        %{
          "type" => "message.part.updated",
          "properties" => %{"part" => %{"type" => "subtask"} = part}
        },
        subtask_message_ids,
        child_session_ids
      ) do
    case part["messageID"] || part["messageId"] do
      msg_id when is_binary(msg_id) ->
        subtask_message_ids = MapSet.put(subtask_message_ids, msg_id)
        subtask_part_id = "subtask-#{msg_id}"
        child_session_id = part["sessionID"] || part["session_id"]

        child_session_ids =
          if is_binary(child_session_id) and child_session_id != "" do
            Map.put(child_session_ids, child_session_id, subtask_part_id)
          else
            child_session_ids
          end

        {subtask_message_ids, child_session_ids}

      _ ->
        {subtask_message_ids, child_session_ids}
    end
  end

  def track_subtask_message_id(_event, subtask_message_ids, child_session_ids) do
    {subtask_message_ids, child_session_ids}
  end

  @doc """
  Checks if an event is a subtask part event.
  """
  def subtask_part?(%{
        "type" => "message.part.updated",
        "properties" => %{"part" => %{"type" => "subtask"}}
      }),
      do: true

  def subtask_part?(_event), do: false

  @doc """
  Tracks a user message ID from a message.updated event.

  Adds the user message ID to `user_message_ids`, skipping messages that
  are already tracked as subtask messages.

  Returns the updated `user_message_ids` MapSet.
  """
  def track_user_message_id(
        %{
          "type" => "message.updated",
          "properties" => %{"info" => %{"role" => "user"} = info}
        },
        user_message_ids,
        subtask_message_ids
      ) do
    case info["id"] || info["messageID"] || info["messageId"] do
      msg_id when is_binary(msg_id) ->
        if MapSet.member?(subtask_message_ids, msg_id) do
          user_message_ids
        else
          MapSet.put(user_message_ids, msg_id)
        end

      _ ->
        user_message_ids
    end
  end

  def track_user_message_id(_event, user_message_ids, _subtask_message_ids) do
    user_message_ids
  end

  @doc """
  Checks if an event part belongs to a tracked user message.

  Defense-in-depth: also checks subtask_message_ids as a safety net
  in case events arrive out of order.
  """
  def user_message_part?(
        %{
          "type" => "message.part.updated",
          "properties" => %{"part" => %{"messageID" => msg_id}}
        },
        user_message_ids,
        subtask_message_ids
      )
      when is_binary(msg_id) do
    MapSet.member?(user_message_ids, msg_id) and
      not MapSet.member?(subtask_message_ids, msg_id)
  end

  def user_message_part?(
        %{
          "type" => "message.part.updated",
          "properties" => %{"part" => %{"messageId" => msg_id}}
        },
        user_message_ids,
        subtask_message_ids
      )
      when is_binary(msg_id) do
    MapSet.member?(user_message_ids, msg_id) and
      not MapSet.member?(subtask_message_ids, msg_id)
  end

  def user_message_part?(_event, _user_message_ids, _subtask_message_ids), do: false
end
