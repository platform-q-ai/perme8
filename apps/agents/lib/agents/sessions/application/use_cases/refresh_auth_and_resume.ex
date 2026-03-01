defmodule Agents.Sessions.Application.UseCases.RefreshAuthAndResume do
  @moduledoc """
  Use case for refreshing auth credentials on a failed task's container
  and resuming the session with the original instruction.

  Used when a task fails with a token expiry error — restarts the
  container, pushes fresh auth from the host's auth.json, then creates
  a new resume task via the facade.

  This use case performs blocking I/O (container restart + health polling)
  and should be called from an async context (e.g., spawned Task) rather
  than directly from a LiveView handler.
  """

  alias Agents.Sessions.Application.SessionsConfig

  require Logger

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository
  @default_container_provider Agents.Sessions.Infrastructure.Adapters.DockerAdapter
  @default_opencode_client Agents.Sessions.Infrastructure.Clients.OpencodeClient
  @default_auth_refresher Agents.Sessions.Application.Services.AuthRefresher

  @doc """
  Refreshes auth and resumes a failed task.

  ## Parameters
  - `task_id` - ID of the failed task
  - `user_id` - The owning user
  - `opts` - Keyword list with:
    - `:task_repo` - Repository module
    - `:container_provider` - Container adapter module
    - `:opencode_client` - Opencode HTTP client module
    - `:auth_refresher` - Auth refresher service module
    - `:resume_fn` - Function `(task_id, attrs, opts) -> {:ok, task} | {:error, term()}`
      for creating the resume task (defaults to `Agents.Sessions.resume_task/3`)

  ## Returns
  - `{:ok, task}` - New resume task domain entity
  - `{:error, :not_found}` - Task not found or not owned by user
  - `{:error, :not_resumable}` - Task is not in a failed state
  - `{:error, :no_container}` - Task has no container_id
  - `{:error, :health_timeout}` - Container failed health check after restart
  - `{:error, term()}` - Container restart or auth refresh failure
  """
  def execute(task_id, user_id, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)
    container_provider = Keyword.get(opts, :container_provider, @default_container_provider)
    opencode_client = Keyword.get(opts, :opencode_client, @default_opencode_client)
    auth_refresher = Keyword.get(opts, :auth_refresher, @default_auth_refresher)

    resume_fn =
      Keyword.get(opts, :resume_fn) ||
        raise ArgumentError, "RefreshAuthAndResume requires :resume_fn option"

    with {:ok, task} <- find_failed_task(task_id, user_id, task_repo),
         :ok <- ensure_container_id(task),
         {:ok, %{port: port}} <- container_provider.restart(task.container_id),
         :ok <- wait_for_health(port, opencode_client),
         {:ok, _providers} <-
           auth_refresher.refresh_auth("http://localhost:#{port}", opencode_client) do
      resume_fn.(task_id, %{instruction: task.instruction, user_id: user_id}, opts)
    end
  end

  defp find_failed_task(task_id, user_id, task_repo) do
    case task_repo.get_task_for_user(task_id, user_id) do
      nil -> {:error, :not_found}
      %{status: "failed"} = task -> {:ok, task}
      _ -> {:error, :not_resumable}
    end
  end

  defp ensure_container_id(%{container_id: nil}), do: {:error, :no_container}
  defp ensure_container_id(%{container_id: _}), do: :ok

  defp wait_for_health(port, opencode_client) do
    max_retries = SessionsConfig.health_check_max_retries()
    interval_ms = SessionsConfig.health_check_interval_ms()
    do_wait_for_health(port, opencode_client, max_retries, interval_ms)
  end

  defp do_wait_for_health(_port, _client, 0, _interval), do: {:error, :health_timeout}

  defp do_wait_for_health(port, opencode_client, retries, interval_ms) do
    case opencode_client.health("http://localhost:#{port}") do
      :ok ->
        :ok

      {:error, _} ->
        Process.sleep(interval_ms)
        do_wait_for_health(port, opencode_client, retries - 1, interval_ms)
    end
  end
end
