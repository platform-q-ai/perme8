defmodule Agents.Sessions.Infrastructure.TaskRunner.ContainerLifecycle do
  @moduledoc """
  Container lifecycle decision logic extracted from TaskRunner.

  Contains pure functions for SSE reconnection decisions and process
  identity checks. Side-effect functions (start/restart/health-check
  handlers, subscribe_to_events, cleanup_container) remain in TaskRunner.
  """

  @doc """
  Determines whether to reconnect the SSE stream after a process DOWN.

  Returns true only if:
  - The DOWN pid matches the current SSE pid
  - We are not already reconnecting
  - The task is in an active status with a session and port
  """
  def should_reconnect_sse?(
        sse_pid,
        sse_reconnecting,
        status,
        session_id,
        container_port,
        down_pid
      ) do
    current_sse_process?(sse_pid, down_pid) and
      not sse_reconnecting and
      task_active_for_reconnect?(status, session_id, container_port)
  end

  @doc """
  Checks if the given pid matches the current SSE process pid.
  """
  def current_sse_process?(pid, pid) when is_pid(pid), do: true
  def current_sse_process?(_, _), do: false

  @doc """
  Checks if the task is in an active state suitable for SSE reconnection.
  """
  def task_active_for_reconnect?(status, session_id, container_port) do
    session_id != nil and container_port != nil and status in [:prompting, :running]
  end
end
