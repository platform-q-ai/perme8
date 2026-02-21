defmodule Agents.Sessions.Infrastructure.Clients.OpencodeClient do
  @moduledoc """
  HTTP/SSE client for the opencode server API.

  Implements the OpencodeClientBehaviour using Req for HTTP and
  raw SSE parsing for the event stream. Aligned with the opencode
  SDK v2 API (https://opencode.ai/docs/sdk).

  All HTTP functions accept an `:http` option for dependency injection
  in tests.
  """

  @behaviour Agents.Sessions.Application.Behaviours.OpencodeClientBehaviour

  require Logger

  # ---- Health ----

  @impl true
  def health(base_url, opts \\ []) do
    http = Keyword.get(opts, :http, &default_http/3)

    case http.(:get, "#{base_url}/global/health", []) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: _}} -> {:error, :unhealthy}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---- Sessions ----

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
      {:ok, %{status: status}} when status in [200, 204] -> :ok
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

  # ---- Permissions ----

  @impl true
  def reply_permission(base_url, request_id, reply, opts \\ []) do
    http = Keyword.get(opts, :http, &default_http/3)

    body = %{requestID: request_id, reply: reply}

    case http.(:post, "#{base_url}/permission/reply", json: body) do
      {:ok, %{status: status}} when status in [200, 204] -> :ok
      {:ok, %{status: status, body: resp_body}} -> {:error, {:http_error, status, resp_body}}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---- SSE Event Stream ----

  @impl true
  def subscribe_events(base_url, caller_pid, opts \\ []) do
    url = "#{base_url}/event"
    http = Keyword.get(opts, :http, nil)

    pid =
      if http do
        # Test mode: use injected http function
        spawn(fn -> test_sse_loop(http, url, caller_pid) end)
      else
        # Production: real SSE connection with Req streaming
        spawn(fn -> sse_connect(url, caller_pid) end)
      end

    Process.monitor(pid)
    {:ok, pid}
  end

  # ---- Private: Production SSE ----

  defp sse_connect(url, caller_pid) do
    buffer = ""

    into_fun = fn {:data, chunk}, {_req, resp} ->
      {events, remaining} = parse_sse_chunk(buffer <> chunk)

      for event <- events do
        send(caller_pid, {:opencode_event, event})
      end

      # Update buffer via process dictionary for simplicity
      Process.put(:sse_buffer, remaining)
      {:cont, {Req.Request.new(), resp}}
    end

    case Req.get(url, into: into_fun, receive_timeout: :infinity) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        send(caller_pid, {:opencode_error, reason})
    end
  rescue
    error ->
      send(caller_pid, {:opencode_error, error})
  end

  defp test_sse_loop(http, url, caller_pid) do
    case http.(:get, url, []) do
      {:ok, %{status: 200}} -> :ok
      {:error, reason} -> send(caller_pid, {:opencode_error, reason})
    end
  end

  # ---- Private: SSE Parsing ----

  @doc false
  def parse_sse_chunk(raw) do
    # SSE format: "event: <type>\ndata: <json>\n\n"
    # Split on double-newline to get complete messages
    parts = String.split(raw, "\n\n")

    # Last part may be incomplete (no trailing \n\n)
    {complete, [remaining]} = Enum.split(parts, -1)

    events =
      complete
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&parse_sse_message/1)
      |> Enum.reject(&is_nil/1)

    {events, remaining}
  end

  defp parse_sse_message(message) do
    lines = String.split(message, "\n")

    {event_type, data} =
      Enum.reduce(lines, {nil, nil}, fn line, {type, data} ->
        cond do
          String.starts_with?(line, "event: ") ->
            {String.trim_leading(line, "event: "), data}

          String.starts_with?(line, "data: ") ->
            {type, String.trim_leading(line, "data: ")}

          true ->
            {type, data}
        end
      end)

    if data do
      case Jason.decode(data) do
        {:ok, parsed} ->
          # Wrap with the event type for easy pattern matching
          if event_type do
            Map.put(parsed, "type", event_type)
          else
            parsed
          end

        {:error, _} ->
          Logger.warning("OpencodeClient: failed to parse SSE data: #{inspect(data)}")
          nil
      end
    else
      nil
    end
  end

  # ---- Private: Default HTTP ----

  defp default_http(method, url, opts) do
    req_opts = [{:method, method}, {:url, url} | opts]

    case Req.request(req_opts) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end
end
