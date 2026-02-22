defmodule Jarga.Webhooks.Infrastructure.Services.HttpClient do
  @moduledoc """
  HTTP client for sending outbound webhook deliveries.

  Uses `Req` for HTTP POST requests with JSON payloads.
  """

  @behaviour Jarga.Webhooks.Application.Behaviours.HttpClientBehaviour

  @default_timeout 30_000

  @impl true
  def post(url, body, opts \\ []) do
    headers = Keyword.get(opts, :headers, %{})
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    req_headers =
      [{"content-type", "application/json"}] ++
        Enum.map(headers, fn {k, v} -> {String.downcase(k), v} end)

    json_body = Jason.encode!(body)

    case Req.post(url,
           body: json_body,
           headers: req_headers,
           receive_timeout: timeout,
           connect_options: [timeout: timeout],
           retry: false,
           redirect: false
         ) do
      {:ok, %Req.Response{status: status, body: resp_body}} ->
        {:ok, %{status: status, body: normalize_body(resp_body)}}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_body(body) when is_binary(body), do: body
  defp normalize_body(body) when is_map(body), do: Jason.encode!(body)
  defp normalize_body(body), do: inspect(body)
end
