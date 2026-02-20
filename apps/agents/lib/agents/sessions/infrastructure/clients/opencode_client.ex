defmodule Agents.Sessions.Infrastructure.Clients.OpencodeClient do
  @moduledoc """
  HTTP/SSE client for communicating with opencode server.

  Uses Req for HTTP calls with dependency injection for testing.
  """

  @behaviour Agents.Sessions.Application.Behaviours.OpencodeClientBehaviour

  @impl true
  def health(base_url, opts \\ []) do
    http = Keyword.get(opts, :http, &default_http/3)

    case http.(:get, "#{base_url}/global/health", []) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: _}} -> {:error, :unhealthy}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def create_session(base_url, opts \\ []) do
    http = Keyword.get(opts, :http, &default_http/3)

    case http.(:post, "#{base_url}/session", json: %{}) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def send_prompt_async(base_url, session_id, parts, opts \\ []) do
    http = Keyword.get(opts, :http, &default_http/3)

    case http.(:post, "#{base_url}/session/#{session_id}/prompt_async", json: %{parts: parts}) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def abort_session(base_url, session_id, opts \\ []) do
    http = Keyword.get(opts, :http, &default_http/3)

    case http.(:post, "#{base_url}/session/#{session_id}/abort", json: %{}) do
      {:ok, %{status: 200}} -> {:ok, true}
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def subscribe_events(base_url, caller_pid, opts \\ []) do
    http = Keyword.get(opts, :http, &default_http/3)

    pid =
      spawn(fn ->
        # In production, this would be a long-lived SSE connection.
        # The http function handles the streaming; events are forwarded
        # to the caller as {:opencode_event, event}.
        case http.(:get, "#{base_url}/event", []) do
          {:ok, %{status: 200}} -> :ok
          {:error, reason} -> send(caller_pid, {:opencode_error, reason})
        end
      end)

    Process.monitor(pid)
    {:ok, pid}
  end

  defp default_http(method, url, opts) do
    req_opts = [{:method, method}, {:url, url} | opts]

    case Req.request(req_opts) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end
end
