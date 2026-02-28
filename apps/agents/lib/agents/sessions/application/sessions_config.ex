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

  @doc "Returns the health check polling interval in milliseconds."
  def health_check_interval_ms do
    config()[:health_check_interval_ms] || 1_000
  end

  @doc "Returns the maximum number of health check retries."
  def health_check_max_retries do
    config()[:health_check_max_retries] || 30
  end

  @doc """
  Returns the environment variables to pass to the container.

  Values that are `{:file, path}` tuples are resolved lazily — the file is
  read and base64-encoded at call time, not at boot time.  This means
  re-authenticated tokens (e.g. OPENCODE_AUTH) are picked up without
  requiring a Phoenix restart.

  ## Options

    * `:file_reader` - Module implementing `read/1`. Defaults to `File`.
  """
  def container_env(opts \\ []) do
    file_reader = Keyword.get(opts, :file_reader, File)

    Application.get_env(:agents, :sessions_env, %{})
    |> Enum.into(%{}, fn
      {key, {:file, path}} -> {key, read_and_encode(path, file_reader)}
      {key, value} -> {key, value}
    end)
  end

  defp read_and_encode(path, file_reader) do
    case file_reader.read(path) do
      {:ok, contents} ->
        Base.encode64(contents)

      {:error, reason} ->
        require Logger
        Logger.warning("Failed to read #{path}: #{inspect(reason)}")
        nil
    end
  end

  @doc "Returns the interval in milliseconds for flushing output_parts to DB while a task is running."
  def output_flush_interval_ms do
    config()[:output_flush_interval_ms] || 3_000
  end

  @doc """
  Returns the interval in milliseconds between auth refresh cycles.

  The auth refresher periodically pushes fresh credentials from the
  host's auth.json to running opencode containers. Default: 30 minutes.
  """
  def auth_refresh_interval_ms do
    config()[:auth_refresh_interval_ms] || :timer.minutes(30)
  end

  @doc """
  Returns the timeout in milliseconds for pending questions.

  If a question from the agent is not answered within this duration,
  the TaskRunner will auto-reject it so the session doesn't block
  indefinitely. Default: 5 minutes.
  """
  def question_timeout_ms do
    config()[:question_timeout_ms] || :timer.minutes(5)
  end

  @doc "Returns the PubSub server name for broadcasting task events."
  def pubsub do
    config()[:pubsub] || Perme8.Events.PubSub
  end

  defp config do
    Application.get_env(:agents, :sessions, [])
  end
end
