defmodule Agents.Sessions.Application.SessionsConfig do
  @moduledoc """
  Configuration accessor for the Sessions bounded context.

  Reads from `Application.get_env(:agents, :sessions)` and `:sessions_env`.
  """

  @doc "Returns the Docker image name for opencode containers."
  def image do
    config()[:image] || "perme8-opencode"
  end

  @doc "Returns the maximum number of concurrent tasks per user."
  def max_concurrent_tasks do
    config()[:max_concurrent_tasks] || 1
  end

  @doc "Returns the task timeout in milliseconds."
  def task_timeout_ms do
    config()[:task_timeout_ms] || 600_000
  end

  @doc "Returns the health check polling interval in milliseconds."
  def health_check_interval_ms do
    config()[:health_check_interval_ms] || 1_000
  end

  @doc "Returns the maximum number of health check retries."
  def health_check_max_retries do
    config()[:health_check_max_retries] || 30
  end

  @doc "Returns the environment variables to pass to the container."
  def container_env do
    Application.get_env(:agents, :sessions_env, %{})
  end

  @doc "Returns the interval in milliseconds for flushing output_parts to DB while a task is running."
  def output_flush_interval_ms do
    config()[:output_flush_interval_ms] || 3_000
  end

  @doc "Returns the PubSub server name for broadcasting task events."
  def pubsub do
    config()[:pubsub] || Perme8.Events.PubSub
  end

  defp config do
    Application.get_env(:agents, :sessions, [])
  end
end
