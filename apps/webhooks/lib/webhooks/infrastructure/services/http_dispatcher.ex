defmodule Webhooks.Infrastructure.Services.HttpDispatcher do
  @moduledoc """
  HTTP dispatcher for outbound webhook delivery.

  Uses Req to POST webhook payloads to subscriber URLs.
  Enforces HTTPS-only in production. Disables redirects to prevent SSRF.
  """

  @behaviour Webhooks.Application.Behaviours.HttpDispatcherBehaviour

  require Logger

  @receive_timeout 10_000

  @impl true
  def dispatch(url, payload_json, headers) do
    with :ok <- validate_url(url) do
      response =
        Req.post!(url,
          body: payload_json,
          headers: headers,
          receive_timeout: @receive_timeout,
          redirect: false
        )

      body = if is_binary(response.body), do: response.body, else: Jason.encode!(response.body)
      {:ok, response.status, body}
    end
  rescue
    e in [Req.TransportError, Mint.TransportError] ->
      Logger.warning("Webhook dispatch failed to #{url}: #{inspect(e)}")
      {:error, Exception.message(e)}

    e ->
      Logger.warning("Webhook dispatch failed to #{url}: #{inspect(e)}")
      {:error, Exception.message(e)}
  end

  defp validate_url(url) do
    uri = URI.parse(url)
    env = Application.get_env(:webhooks, :env)

    cond do
      uri.scheme == "https" ->
        :ok

      # Allow HTTP in dev/test for local testing (e.g., Bypass)
      uri.scheme == "http" and env in [:test, :dev] ->
        :ok

      true ->
        Logger.warning("Webhook dispatch rejected non-HTTPS URL: #{url}")
        {:error, :https_required}
    end
  end
end
