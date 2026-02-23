defmodule Webhooks.Infrastructure.Services.HttpDispatcher do
  @moduledoc """
  HTTP dispatcher for outbound webhook delivery.

  Uses Req to POST webhook payloads to subscriber URLs.
  """

  @behaviour Webhooks.Application.Behaviours.HttpDispatcherBehaviour

  require Logger

  @receive_timeout 10_000

  @impl true
  def dispatch(url, payload_json, headers) do
    response =
      Req.post!(url,
        body: payload_json,
        headers: headers,
        receive_timeout: @receive_timeout
      )

    {:ok, response.status, response.body}
  rescue
    e in [Req.TransportError, Mint.TransportError] ->
      Logger.warning("Webhook dispatch failed to #{url}: #{inspect(e)}")
      {:error, Exception.message(e)}

    e ->
      Logger.warning("Webhook dispatch failed to #{url}: #{inspect(e)}")
      {:error, Exception.message(e)}
  end
end
