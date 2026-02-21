defmodule Agents.Sessions.Application.Behaviours.ContainerProviderBehaviour do
  @moduledoc """
  Behaviour defining the contract for container lifecycle management.

  Implementations must provide start, stop, and status operations
  for ephemeral containers running coding agents.
  """

  @callback start(image :: String.t(), opts :: keyword()) ::
              {:ok, %{container_id: String.t(), port: integer()}} | {:error, term()}

  @callback stop(container_id :: String.t()) :: :ok | {:error, term()}

  @callback status(container_id :: String.t()) ::
              {:ok, :running | :stopped | :not_found} | {:error, term()}
end
