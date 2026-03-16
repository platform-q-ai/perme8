defmodule Agents.Sessions.Infrastructure.TaskRunner.QuestionHandler do
  @moduledoc """
  Question lifecycle helper functions extracted from TaskRunner.

  Contains pure functions for extracting tool names, validating session
  summaries, and sanitizing error messages. Side-effect functions
  (cancel_question_timeout, auto_reject, clear_pending_question) remain
  in TaskRunner.
  """

  @doc """
  Extracts a printable tool name from permission.asked properties.

  The "tool" field can be a map (e.g. %{"callID" => ..., "messageID" => ...})
  so we fall back to the "permission" type or "name" field.
  """
  def extract_tool_name(%{"tool" => tool}) when is_binary(tool), do: tool
  def extract_tool_name(%{"permission" => perm}) when is_binary(perm), do: perm
  def extract_tool_name(%{"name" => name}) when is_binary(name), do: name
  def extract_tool_name(_), do: "unknown"

  @doc """
  Validates that a session summary has exactly the expected shape:
  `%{"files" => int, "additions" => int, "deletions" => int}` with no extra keys.
  """
  def valid_session_summary?(
        %{"files" => files, "additions" => additions, "deletions" => deletions} = summary
      )
      when is_integer(files) and is_integer(additions) and is_integer(deletions) do
    map_size(summary) == 3
  end

  def valid_session_summary?(_summary), do: false

  @doc """
  Sanitizes a fresh start failure reason into a user-safe message.

  Strips raw container output and internal details.
  """
  def sanitize_fresh_start_reason({:docker_prepare_fresh_start_failed, exit_code, _output}) do
    "container repo sync failed (exit #{exit_code})"
  end

  def sanitize_fresh_start_reason({:auth_refresh_failed, _provider}), do: "auth refresh failed"

  def sanitize_fresh_start_reason(_), do: "internal preparation error"
end
