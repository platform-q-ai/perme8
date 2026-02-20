defmodule Agents.Sessions.Application.Behaviours.OpencodeClientBehaviour do
  @moduledoc """
  Behaviour defining the contract for communicating with an opencode server.

  Implementations must provide HTTP/SSE operations for managing
  coding sessions within opencode containers.
  """

  @callback health(base_url :: String.t()) :: :ok | {:error, term()}

  @callback create_session(base_url :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback send_prompt_async(
              base_url :: String.t(),
              session_id :: String.t(),
              parts :: list(),
              opts :: keyword()
            ) :: :ok | {:error, term()}

  @callback abort_session(base_url :: String.t(), session_id :: String.t()) ::
              {:ok, boolean()} | {:error, term()}

  @callback subscribe_events(base_url :: String.t(), caller_pid :: pid()) ::
              {:ok, pid()} | {:error, term()}
end
