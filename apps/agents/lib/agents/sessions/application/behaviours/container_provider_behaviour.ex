defmodule Agents.Sessions.Application.Behaviours.ContainerProviderBehaviour do
  @moduledoc """
  Behaviour defining the contract for container lifecycle management.

  Containers are task-scoped: they persist across multiple instructions
  and are only destroyed on explicit user delete.

  - `start/2` — Creates and starts a new container
  - `stop/1` — Gracefully stops a container (preserves filesystem for resume)
  - `remove/1` — Permanently destroys a container (used on explicit delete)
  - `restart/1` — Restarts a stopped container and re-discovers the mapped port
  - `status/1` — Inspects container state
  - `stats/1` — Returns CPU and memory usage for a running container
  """

  @callback start(image :: String.t(), opts :: keyword()) ::
              {:ok, %{container_id: String.t(), port: integer()}} | {:error, term()}

  @callback stop(container_id :: String.t()) :: :ok | {:error, term()}

  @callback remove(container_id :: String.t()) :: :ok | {:error, term()}

  @callback restart(container_id :: String.t()) ::
              {:ok, %{port: integer()}} | {:error, term()}

  @callback status(container_id :: String.t()) ::
              {:ok, :running | :stopped | :not_found} | {:error, term()}

  @callback stats(container_id :: String.t()) ::
              {:ok, %{cpu_percent: float(), memory_usage: integer(), memory_limit: integer()}}
              | {:error, term()}
end
