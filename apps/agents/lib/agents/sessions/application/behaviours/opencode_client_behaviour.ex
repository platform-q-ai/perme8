defmodule Agents.Sessions.Application.Behaviours.OpencodeClientBehaviour do
  @moduledoc """
  Behaviour defining the contract for communicating with an opencode server.

  Aligned with the opencode SDK API (https://opencode.ai/docs/sdk):
  - Sessions: create, prompt_async, abort
  - Events: SSE subscription for real-time streaming
  - Permissions: auto-reply to tool permission requests
  - Health: global health check
  """

  @doc """
  Check the health of the opencode server.

  Hits `GET /global/health` and expects a 200 response.
  """
  @callback health(base_url :: String.t()) :: :ok | {:error, term()}

  @doc """
  Create a new opencode session.

  Posts to `POST /session` with an optional title.
  Returns `{:ok, %{"id" => session_id, ...}}` on success.
  """
  @callback create_session(base_url :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Send an async prompt to a session.

  Posts to `POST /session/:id/prompt_async`.
  Returns `:ok` on 204 (accepted for processing).
  """
  @callback send_prompt_async(
              base_url :: String.t(),
              session_id :: String.t(),
              parts :: list(),
              opts :: keyword()
            ) :: :ok | {:error, term()}

  @doc """
  Abort a running session.

  Posts to `POST /session/:id/abort`.
  """
  @callback abort_session(base_url :: String.t(), session_id :: String.t()) ::
              {:ok, boolean()} | {:error, term()}

  @doc """
  Subscribe to the SSE event stream.

  Connects to `GET /event` and forwards events to the caller process as:
  - `{:opencode_event, event}` for each parsed SSE event
  - `{:opencode_error, reason}` on connection failure

  Events follow the opencode SDK types:
  - `"session.status"` - session status changes (running, idle, error)
  - `"message.part.updated"` - text/tool output streaming
  - `"permission.asked"` - tool permission requests
  - `"session.error"` - session-level errors
  - `"server.connected"` - initial connection confirmation
  """
  @callback subscribe_events(base_url :: String.t(), caller_pid :: pid()) ::
              {:ok, pid()} | {:error, term()}

  @doc """
  Reply to a permission request.

  Posts to `POST /session/:sessionID/permissions/:permissionID` with the response.
  Response values: "once", "always", "reject"
  """
  @callback reply_permission(
              base_url :: String.t(),
              session_id :: String.t(),
              permission_id :: String.t(),
              response :: String.t(),
              opts :: keyword()
            ) :: :ok | {:error, term()}
end
