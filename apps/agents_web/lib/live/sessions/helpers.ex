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

  @doc "Returns true if the task is in an active (non-terminal) state."
  def active_task?(%{status: status}), do: status in ["pending", "starting", "running"]

  @doc "Returns true if the task is currently running."
  def task_running?(nil), do: false
  def task_running?(task), do: active_task?(task)

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

  @doc "Filters tasks belonging to a specific container."
  def session_tasks(tasks, container_id) do
    tasks
    |> Enum.filter(&(&1.container_id == container_id))
  end

  @doc "Finds the current task for a container (prefers running tasks)."
  def find_current_task(tasks, nil), do: Enum.find(tasks, &active_task?/1)

  def find_current_task(tasks, container_id) do
    session_tasks =
      tasks
      |> Enum.filter(&(&1.container_id == container_id))

    # Prefer running task, otherwise latest
    Enum.find(session_tasks, &active_task?/1) || List.first(session_tasks)
  end

  @doc "Maps a task error reason to a user-friendly message."
  def task_error_message(:instruction_required), do: "Instruction is required"
  def task_error_message(:not_resumable), do: "This session cannot be resumed"
  def task_error_message(:no_container), do: "No container available for resume"
  def task_error_message(:no_session), do: "No session available for resume"
  def task_error_message(:health_timeout), do: "Container failed to become healthy after restart"
  def task_error_message(_), do: "Failed to create task"

  @doc "Polls container stats for all active sessions."
  def poll_running_session_stats(sessions) do
    sessions
    |> Enum.filter(&(&1.latest_status in ["running", "starting", "pending"]))
    |> Enum.reduce(%{}, fn session, acc ->
      case fetch_container_stats(session.container_id) do
        {:ok, stats_map} -> Map.put(acc, session.container_id, stats_map)
        :error -> acc
      end
    end)
  end

  @doc "Fetches and normalizes container stats."
  def fetch_container_stats(container_id) do
    alias Agents.Sessions

    case Sessions.get_container_stats(container_id) do
      {:ok, stats} ->
        mem_percent =
          if stats.memory_limit > 0,
            do: Float.round(stats.memory_usage / stats.memory_limit * 100, 1),
            else: 0.0

        {:ok,
         %{
           cpu_percent: stats.cpu_percent,
           memory_percent: mem_percent,
           memory_usage: stats.memory_usage,
           memory_limit: stats.memory_limit
         }}

      {:error, _} ->
        :error
    end
  end

  @doc "Updates a single task's status in the task list."
  def update_task_in_list(tasks, task_id, status) do
    Enum.map(tasks, fn
      %{id: ^task_id} = task -> Map.put(task, :status, status)
      task -> task
    end)
  end
end
