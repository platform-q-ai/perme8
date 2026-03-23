defmodule Agents.Sessions.Application.SessionsConfig do
  @moduledoc """
  Configuration accessor for the Sessions bounded context.

  Reads from `Application.get_env(:agents, :sessions)` and `:sessions_env`.
  """

  @doc "Returns the default Docker image name for containers."
  def image do
    config()[:image] || "perme8-opencode"
  end

  @doc """
  Returns the list of available Docker images for sessions.

  Each entry is a map with `:name` (the Docker image name) and
  `:label` (a human-readable display name).
  """
  def available_images do
    config()[:available_images] ||
      [
        %{name: "perme8-opencode", label: "OpenCode"},
        %{name: "perme8-opencode-light", label: "OpenCode Light"},
        %{name: "perme8-pi", label: "Pi"}
      ]
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
  Returns the timeout in milliseconds for pending questions.

  If a question from the agent is not answered within this duration,
  the TaskRunner will auto-reject it so the session doesn't block
  indefinitely. Default: 5 minutes.
  """
  def question_timeout_ms do
    config()[:question_timeout_ms] || :timer.minutes(5)
  end

  @doc "Returns the default concurrency limit for task queuing."
  def default_concurrency_limit do
    config()[:default_concurrency_limit] || 2
  end

  @doc "Returns the default warm cache limit for container pre-warming."
  def default_warm_cache_limit do
    config()[:default_warm_cache_limit] || 2
  end

  @doc "Returns the PubSub server name for broadcasting task events."
  def pubsub do
    config()[:pubsub] || Perme8.Events.PubSub
  end

  @doc "Returns whether GitHub ticket sync is enabled."
  def github_sync_enabled? do
    config()[:github_sync_enabled] != false
  end

  @doc "Returns idle timeout (ms) before an idle ticket session is suspended."
  def idle_suspend_timeout_ms do
    config()[:idle_suspend_timeout_ms] || :timer.minutes(10)
  end

  @doc "Returns the optional setup instruction for a setup phase."
  def setup_phase_instruction(phase) when phase in [:on_create, :on_resume] do
    config()
    |> Keyword.get(:setup_phases, %{})
    |> Map.get(phase)
  end

  @doc "Returns the GitHub org/owner for issue queries."
  def github_org do
    config()[:github_org] || config()[:github_project_org] || "platform-q-ai"
  end

  @doc "Returns the GitHub repository name for issue queries."
  def github_repo do
    config()[:github_repo] || "perme8"
  end

  @doc "Returns GitHub sync polling interval in milliseconds."
  def github_poll_interval_ms do
    config()[:github_poll_interval_ms] || 15_000
  end

  @doc "Returns the GitHub token used for API queries."
  def github_token do
    config()[:github_token]
  end

  defp config do
    Application.get_env(:agents, :sessions, [])
  end
end
