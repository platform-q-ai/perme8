defmodule WebhooksApi.InboundLogJSON do
  @moduledoc "JSON rendering for Inbound Log API endpoints."

  def index(%{logs: logs}) do
    %{data: Enum.map(logs, &log_data/1)}
  end

  def error(%{message: message}) do
    %{error: message}
  end

  defp log_data(log) do
    %{
      id: log.id,
      event_type: log.event_type,
      payload: log.payload,
      signature_valid: log.signature_valid,
      source_ip: log.source_ip,
      received_at: log.received_at
    }
  end
end
