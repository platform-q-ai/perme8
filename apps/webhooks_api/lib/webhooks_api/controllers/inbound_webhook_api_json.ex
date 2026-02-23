defmodule WebhooksApi.InboundWebhookApiJSON do
  @moduledoc "JSON rendering for Inbound Webhook API endpoints."

  def received(%{}) do
    %{data: %{status: "received"}}
  end

  def error(%{message: message}) do
    %{error: message}
  end
end
