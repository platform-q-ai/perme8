defmodule JargaApi.InboundWebhookApiJSON do
  @moduledoc """
  JSON rendering for Inbound Webhook API endpoints.
  """

  @doc """
  Renders a successful inbound webhook receipt.
  """
  def received(_assigns) do
    %{data: %{status: "accepted"}}
  end

  @doc """
  Renders inbound webhook audit logs.
  """
  def logs(%{logs: logs}) do
    %{data: Enum.map(logs, &log_data/1)}
  end

  @doc """
  Renders an error message.
  """
  def error(%{message: message}) do
    %{error: message}
  end

  defp log_data(log) do
    %{
      id: log.id,
      event_type: log.event_type,
      payload: log.payload,
      source_ip: log.source_ip,
      signature_valid: log.signature_valid,
      handler_result: log.handler_result,
      received_at: log.received_at,
      inserted_at: log.inserted_at
    }
  end
end
