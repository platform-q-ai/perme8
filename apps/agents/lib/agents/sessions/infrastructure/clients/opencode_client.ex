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
  def reply_permission(base_url, session_id, permission_id, response, opts \\ []) do
    http = Keyword.get(opts, :http, &default_http/3)

    url = "#{base_url}/session/#{session_id}/permissions/#{permission_id}"
    body = %{response: response}

    case http.(:post, url, json: body) do
      {:ok, %{status: status}} when status in [200, 204] -> :ok
      {:ok, %{status: status, body: resp_body}} -> {:error, {:http_error, status, resp_body}}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---- Questions ----

  @impl true
  def reply_question(base_url, request_id, answers, opts \\ []) do
    http = Keyword.get(opts, :http, &default_http/3)

    url = "#{base_url}/question/#{request_id}/reply"
    body = %{answers: answers}

    case http.(:post, url, json: body) do
      {:ok, %{status: status}} when status in [200, 204] -> :ok
      {:ok, %{status: status, body: resp_body}} -> {:error, {:http_error, status, resp_body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def reject_question(base_url, request_id, opts \\ []) do
    http = Keyword.get(opts, :http, &default_http/3)

    url = "#{base_url}/question/#{request_id}/reject"

    case http.(:post, url, json: %{}) do
      {:ok, %{status: status}} when status in [200, 204] -> :ok
      {:ok, %{status: status, body: resp_body}} -> {:error, {:http_error, status, resp_body}}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---- Auth Management ----

  @impl true
  def set_auth(base_url, provider_id, credentials, opts \\ []) do
    http = Keyword.get(opts, :http, &default_http/3)

    case http.(:put, "#{base_url}/auth/#{provider_id}", json: credentials) do
      {:ok, %{status: 200}} -> {:ok, true}
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def list_providers(base_url, opts \\ []) do
    http = Keyword.get(opts, :http, &default_http/3)

    case http.(:get, "#{base_url}/provider", []) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---- Retrieval APIs ----

  @impl true
  def list_sessions(base_url, opts \\ []) do
    http = Keyword.get(opts, :http, &default_http/3)

    case http.(:get, "#{base_url}/session", []) do
      {:ok, %{status: 200, body: body}} when is_list(body) -> {:ok, body}
      {:ok, %{status: 200, body: %{"data" => data}}} when is_list(data) -> {:ok, data}
      {:ok, %{status: 200, body: body}} -> {:ok, List.wrap(body)}
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get_session(base_url, session_id, opts \\ []) do
    http = Keyword.get(opts, :http, &default_http/3)

    case http.(:get, "#{base_url}/session/#{session_id}", []) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl true
  def get_messages(base_url, session_id, opts \\ []) do
    http = Keyword.get(opts, :http, &default_http/3)

    case http.(:get, "#{base_url}/session/#{session_id}/message", []) do
      {:ok, %{status: 200, body: body}} when is_list(body) -> {:ok, body}
      {:ok, %{status: 200, body: %{"data" => data}}} when is_list(data) -> {:ok, data}
      {:ok, %{status: 200, body: body}} -> {:ok, List.wrap(body)}
      {:ok, %{status: status, body: body}} -> {:error, {:http_error, status, body}}
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

  # Max retries and delay for initial SSE connection. After a container
  # restart the health endpoint may respond before the SSE endpoint is
  # ready, so we retry transient connection errors (econnrefused, etc.).
  @sse_connect_max_retries 5
  @sse_connect_retry_delay_ms 1_000

  defp sse_connect(url, caller_pid) do
    sse_connect_with_retry(url, caller_pid, @sse_connect_max_retries)
  end

  defp sse_connect_with_retry(url, caller_pid, retries_left) do
    Process.put(:sse_buffer, "")

    into_fun = fn {:data, chunk}, {_req, resp} ->
      buffer = Process.get(:sse_buffer, "")
      {events, remaining} = parse_sse_chunk(buffer <> chunk)

      for event <- events do
        send(caller_pid, {:opencode_event, event})
      end

      Process.put(:sse_buffer, remaining)
      {:cont, {Req.Request.new(), resp}}
    end

    case Req.get(url, into: into_fun, receive_timeout: :infinity) do
      {:ok, _} ->
        :ok

      {:error, %Req.TransportError{reason: reason}}
      when reason in [:econnrefused, :timeout, :closed] and retries_left > 0 ->
        Logger.info("SSE connect to #{url} got #{reason}, retrying (#{retries_left} left)")

        Process.sleep(@sse_connect_retry_delay_ms)
        sse_connect_with_retry(url, caller_pid, retries_left - 1)

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
            {String.replace_prefix(line, "event: ", ""), data}

          String.starts_with?(line, "data: ") ->
            {type, String.replace_prefix(line, "data: ", "")}

          true ->
            {type, data}
        end
      end)

    data && decode_sse_data(data, event_type)
  end

  defp decode_sse_data(data, event_type) do
    case Jason.decode(data) do
      {:ok, parsed} ->
        maybe_add_event_type(parsed, event_type)

      {:error, _} ->
        Logger.warning("OpencodeClient: failed to parse SSE data: #{inspect(data)}")
        nil
    end
  end

  defp maybe_add_event_type(parsed, nil), do: parsed
  defp maybe_add_event_type(parsed, event_type), do: Map.put(parsed, "type", event_type)

  # ---- Private: Default HTTP ----

  defp default_http(method, url, opts) do
    req_opts = [{:method, method}, {:url, url} | opts]

    case Req.request(req_opts) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end
end
