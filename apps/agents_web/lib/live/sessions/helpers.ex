defmodule AgentsWeb.SessionsLive.Helpers do
  @moduledoc """
  Pure helper functions for the Sessions LiveView.

  Contains formatting, filtering, and display logic that doesn't
  depend on socket state. Used by the LiveView and its template.
  """

  @doc "Formats a token count for display (e.g., 5200 → \"5.2k\")."
  def format_token_count(nil), do: "-"
  def format_token_count(n) when is_number(n) and n >= 1000, do: "#{Float.round(n / 1000, 1)}k"
  def format_token_count(n) when is_number(n), do: "#{n}"
  def format_token_count(_), do: "-"

  @doc "Truncates an instruction string to a maximum length."
  def truncate_instruction(instruction, max_length) do
    if String.length(instruction) > max_length do
      String.slice(instruction, 0, max_length) <> "..."
    else
      instruction
    end
  end

  @doc "Formats an error value for display."
  def format_error(error) when is_binary(error), do: error
  def format_error(%{"message" => msg}), do: msg
  def format_error(%{"data" => %{"message" => msg}}), do: msg
  def format_error(error), do: inspect(error)

  @doc "Returns a human-readable relative time string."
  def relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86_400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  @doc "Checks whether an error string indicates an auth failure."
  def auth_error?(error) when is_binary(error) do
    error =~ "Token refresh failed" or
      error =~ "token expired" or
      error =~ "authentication failed" or
      error =~ "unauthorized"
  end

  def auth_error?(_), do: false

  alias AgentsWeb.SessionsLive.SessionStateMachine

  @doc "Returns true if the task is in an active (non-terminal) state."
  def active_task?(%{status: _} = task),
    do: task |> SessionStateMachine.state_from_task() |> SessionStateMachine.active?()

  @doc "Returns true if the task is currently running."
  def task_running?(nil), do: false

  def task_running?(%{status: _} = task),
    do: task |> SessionStateMachine.state_from_task() |> SessionStateMachine.task_running?()

  @doc "Returns true if the session can be deleted (task is in terminal state)."
  def session_deletable?(sessions, container_id) do
    case Enum.find(sessions, &(&1.container_id == container_id)) do
      %{latest_status: status} -> status in ["completed", "failed", "cancelled"]
      _ -> false
    end
  end

  @doc "Returns true if the task can be resumed."
  def resumable_task?(%{status: status, container_id: cid, session_id: sid})
      when status in ["completed", "failed", "cancelled"] and
             not is_nil(cid) and not is_nil(sid),
      do: true

  def resumable_task?(_), do: false

  @doc "Extracts the text of the last user message from output_parts."
  def last_user_message(output_parts) when is_list(output_parts) do
    output_parts
    |> Enum.reverse()
    |> Enum.find_value(fn
      {:user, _id, text} -> text
      {:user_pending, _id, text} -> text
      _ -> nil
    end)
  end

  def last_user_message(_), do: nil

  @doc "Finds the current task for a container (prefers running tasks)."
  def find_current_task(tasks, nil), do: Enum.find(tasks, &active_task?/1)

  def find_current_task(tasks, container_id) do
    case String.split(container_id, ":", parts: 2) do
      ["task", task_id] ->
        Enum.find(tasks, &(&1.id == task_id))

      _ ->
        session_tasks =
          tasks
          |> Enum.filter(&(&1.container_id == container_id))

        # Prefer running task, otherwise latest
        Enum.find(session_tasks, &active_task?/1) || List.first(session_tasks)
    end
  end

  @doc "Returns a human-readable label for a Docker image name."
  def image_label(image_name) do
    Agents.Sessions.image_label(image_name)
  end

  @doc "Returns true if a specific task is currently being auth-refreshed."
  def auth_refreshing?(auth_refreshing, task_id) when is_map(auth_refreshing) do
    Map.has_key?(auth_refreshing, task_id)
  end

  def auth_refreshing?(_, _), do: false

  @doc "Returns true if any sessions have auth errors and are refreshable."
  def has_auth_refresh_candidates?(sessions) do
    Enum.any?(sessions, fn s ->
      s.latest_status == "failed" and auth_error?(Map.get(s, :latest_error))
    end)
  end

  @doc "Maps a task error reason to a user-friendly message."
  def task_error_message(:instruction_required), do: "Instruction is required"
  def task_error_message(:already_active), do: "This session is already running"
  def task_error_message(:not_resumable), do: "This session cannot be resumed"
  def task_error_message(:no_container), do: "No container available for resume"
  def task_error_message(:no_session), do: "No session available for resume"
  def task_error_message(:health_timeout), do: "Container failed to become healthy after restart"

  def task_error_message({:auth_refresh_failed, failures}) when is_list(failures) do
    details =
      Enum.map_join(failures, "; ", fn %{provider: provider, reason: reason} ->
        "#{provider}: #{format_auth_refresh_reason(reason)}"
      end)

    if details == "" do
      "Auth refresh failed"
    else
      "Auth refresh failed (#{details})"
    end
  end

  def task_error_message({:error, reason}), do: task_error_message(reason)
  def task_error_message(_), do: "Failed to create task"

  defp format_auth_refresh_reason({:http_error, status, body}) do
    body_text =
      cond do
        is_binary(body) -> body
        is_map(body) -> Jason.encode!(body)
        true -> inspect(body)
      end

    "HTTP #{status}: #{String.slice(body_text, 0, 180)}"
  end

  defp format_auth_refresh_reason(reason), do: inspect(reason)

  @doc "Converts a title string to a lowercase hyphenated slug for data-testid values."
  def slugify(nil), do: ""

  def slugify(title) when is_binary(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.trim()
    |> String.replace(~r/\s+/, "-")
  end

  @doc """
  Extracts todo items from persisted session data for display in session cards.

  The DB column stores `%{"items" => [%{"id" => ..., "title" => ..., "status" => ..., "position" => ...}, ...]}`.
  Returns a list of maps with atom keys, or an empty list if no todos exist.
  """
  def session_todo_items(%{todo_items: %{"items" => items}}) when is_list(items) do
    Enum.map(items, fn item ->
      %{
        id: item["id"],
        title: item["title"],
        status: item["status"],
        position: item["position"]
      }
    end)
  end

  def session_todo_items(_session), do: []

  @doc "Returns true when the inline initial user instruction bubble should be shown."
  def show_initial_instruction?(nil, _output_parts), do: false

  def show_initial_instruction?(%{instruction: instruction}, output_parts)
      when is_list(output_parts) do
    instruction_text = String.trim(instruction || "")

    if instruction_text == "" do
      false
    else
      not Enum.any?(output_parts, fn
        {:user, _id, text} -> String.trim(text || "") == instruction_text
        {:user_pending, _id, text} -> String.trim(text || "") == instruction_text
        _ -> false
      end)
    end
  end

  def show_initial_instruction?(_task, _output_parts), do: false

  @doc """
  Formats duration between two DateTimes as a human-readable string.

  For running sessions (completed_at is nil), uses `now` as the end time.
  Returns nil if started_at is nil (session hasn't started).

  ## Examples

      iex> format_duration(~U[2026-01-01 00:00:00Z], ~U[2026-01-01 00:05:30Z])
      "5m 30s"

      iex> format_duration(~U[2026-01-01 00:00:00Z], nil, ~U[2026-01-01 01:05:00Z])
      "1h 5m"
  """
  def format_duration(started_at, completed_at \\ nil, now \\ nil)
  def format_duration(nil, _completed_at, _now), do: nil

  def format_duration(started_at, completed_at, now) do
    end_time = completed_at || now || DateTime.utc_now()
    diff = max(DateTime.diff(end_time, started_at, :second), 0)
    format_seconds(diff)
  end

  defp format_seconds(seconds) when seconds < 60, do: "#{seconds}s"

  defp format_seconds(seconds) when seconds < 3600 do
    m = div(seconds, 60)
    s = rem(seconds, 60)
    "#{m}m #{s}s"
  end

  defp format_seconds(seconds) when seconds < 86_400 do
    h = div(seconds, 3600)
    m = div(rem(seconds, 3600), 60)
    "#{h}h #{m}m"
  end

  defp format_seconds(seconds) do
    d = div(seconds, 86_400)
    h = div(rem(seconds, 86_400), 3600)
    "#{d}d #{h}h"
  end

  @doc """
  Formats file change summary for display.

  Returns a string like "3 files +42 -18" or nil if no summary is available.
  """
  def format_file_stats(nil), do: nil
  def format_file_stats(%{"files" => 0}), do: nil

  def format_file_stats(%{"files" => files, "additions" => adds, "deletions" => dels})
      when is_integer(files) and is_integer(adds) and is_integer(dels) do
    file_label = if files == 1, do: "file", else: "files"
    "#{files} #{file_label} +#{adds} -#{dels}"
  end

  def format_file_stats(_), do: nil

  @doc "Returns CSS classes for ticket priority badge."
  def ticket_priority_class("Need"), do: "badge-error text-white"
  def ticket_priority_class("Want"), do: "badge-warning"
  def ticket_priority_class("Nice to have"), do: "badge-ghost"
  def ticket_priority_class(_), do: "badge-ghost"

  @doc "Returns CSS classes for ticket board status badge."
  def ticket_status_class("Backlog"), do: "badge-outline"
  def ticket_status_class("Ready"), do: "badge-info"
  def ticket_status_class(_), do: "badge-ghost"

  @doc "Returns CSS classes for ticket size badge."
  def ticket_size_class("XL"), do: "badge-error text-white"
  def ticket_size_class("L"), do: "badge-warning"
  def ticket_size_class("M"), do: "badge-info"
  def ticket_size_class("S"), do: "badge-success"
  def ticket_size_class("XS"), do: "badge-ghost"
  def ticket_size_class(_), do: "badge-outline"

  @doc "Returns CSS classes for associated session state badge."
  def ticket_session_state_class("running"), do: "badge-success"
  def ticket_session_state_class("completed"), do: "badge-primary"
  def ticket_session_state_class("paused"), do: "badge-warning"
  def ticket_session_state_class(_), do: "badge-ghost"

  @doc "Returns a human-readable label for a queue lane."
  def lane_status_label(:processing), do: "Processing"
  def lane_status_label(:warm), do: "Warm"
  def lane_status_label(:cold), do: "Cold"
  def lane_status_label(:awaiting_feedback), do: "Awaiting Feedback"
  def lane_status_label(:retry_pending), do: "Retry Pending"
  def lane_status_label(_), do: "Unknown"

  @doc "Returns CSS class for a lane type."
  def lane_css_class(:processing), do: "lane-processing"
  def lane_css_class(:warm), do: "lane-warm"
  def lane_css_class(:cold), do: "lane-cold"
  def lane_css_class(:awaiting_feedback), do: "lane-awaiting-feedback"
  def lane_css_class(:retry_pending), do: "lane-retry-pending"
  def lane_css_class(_), do: ""

  @label_classes %{
    "bug" => "badge-error",
    "fix" => "badge-error",
    "urgent" => "badge-error",
    "critical" => "badge-error",
    "security" => "badge-error",
    "feature" => "badge-success",
    "enhancement" => "badge-success",
    "improvement" => "badge-success",
    "frontend" => "badge-info",
    "ui" => "badge-info",
    "ux" => "badge-info",
    "backend" => "badge-secondary",
    "api" => "badge-secondary",
    "agents" => "badge-primary",
    "agents_web" => "badge-primary",
    "agents_api" => "badge-primary",
    "identity" => "badge-secondary",
    "jarga" => "badge-accent",
    "chat" => "badge-info",
    "webhooks" => "badge-warning",
    "perme8_tools" => "badge-neutral",
    "docs" => "badge-accent",
    "documentation" => "badge-accent",
    "chore" => "badge-ghost",
    "maintenance" => "badge-ghost",
    "refactor" => "badge-warning",
    "blocked" => "badge-warning"
  }

  @doc "Returns CSS classes for GitHub label badges."
  def ticket_label_class(label) when is_binary(label) do
    Map.get(@label_classes, String.downcase(String.trim(label)), "badge-outline")
  end

  def ticket_label_class(_), do: "badge-outline"

  @doc """
  Filters sessions by a search query (case-insensitive match against title).
  Returns all sessions when query is empty.
  """
  def filter_sessions_by_search(sessions, ""), do: sessions
  def filter_sessions_by_search(sessions, nil), do: sessions

  def filter_sessions_by_search(sessions, query) do
    downcased = String.downcase(query)

    Enum.filter(sessions, fn session ->
      title = session.title || ""
      String.contains?(String.downcase(title), downcased)
    end)
  end

  @doc """
  Filters tickets by a search query (case-insensitive match against title, number, and labels).
  Returns all tickets when query is empty.
  """
  def filter_tickets_by_search(tickets, ""), do: tickets
  def filter_tickets_by_search(tickets, nil), do: tickets

  def filter_tickets_by_search(tickets, query) do
    downcased = String.downcase(query)

    Enum.filter(tickets, fn ticket ->
      title_match = String.contains?(String.downcase(ticket.title || ""), downcased)
      number_match = Integer.to_string(ticket.number) =~ downcased

      label_match =
        Enum.any?(ticket.labels || [], fn label ->
          String.contains?(String.downcase(label), downcased)
        end)

      title_match or number_match or label_match
    end)
  end

  @doc """
  Filters sessions by status. :all returns everything.
  Triage statuses: :awaiting_feedback, :completed, :cancelled
  Build statuses: :failed, :queued, :running
  """
  def filter_sessions_by_status(sessions, :all), do: sessions

  def filter_sessions_by_status(sessions, status) do
    status_str = Atom.to_string(status)

    Enum.filter(sessions, fn session ->
      case status_str do
        "running" -> session.latest_status in ["pending", "starting", "running"]
        other -> session.latest_status == other
      end
    end)
  end

  @doc """
  Filters tickets by status. :all returns everything.
  """
  def filter_tickets_by_status(tickets, :all), do: tickets

  def filter_tickets_by_status(tickets, status) do
    status_str = Atom.to_string(status)

    Enum.filter(tickets, fn ticket ->
      case status_str do
        "running" -> ticket.task_status in ["pending", "starting", "running"]
        other -> ticket.task_status == other
      end
    end)
  end
end
