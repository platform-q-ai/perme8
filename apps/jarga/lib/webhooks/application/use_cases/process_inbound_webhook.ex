defmodule Jarga.Webhooks.Application.UseCases.ProcessInboundWebhook do
  @moduledoc """
  Use case for processing an inbound webhook request.

  Verifies HMAC signature, parses payload, records audit log, and emits event.
  """

  alias Jarga.Webhooks.Domain.Events.InboundWebhookReceived
  alias Jarga.Webhooks.Domain.Policies.SignaturePolicy

  @default_inbound_webhook_repository Jarga.Webhooks.Infrastructure.Repositories.InboundWebhookRepository
  @default_event_bus Perme8.Events.EventBus

  def execute(params, opts \\ []) do
    %{
      workspace_id: workspace_id,
      raw_body: raw_body,
      signature: signature,
      source_ip: source_ip,
      workspace_secret: workspace_secret
    } = params

    inbound_webhook_repository =
      Keyword.get(opts, :inbound_webhook_repository, @default_inbound_webhook_repository)

    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    event_bus_opts = Keyword.get(opts, :event_bus_opts, [])

    with :ok <- validate_signature_present(signature),
         {:ok, hex_sig} <- SignaturePolicy.parse_signature_header(signature),
         :ok <- verify_signature(raw_body, workspace_secret, hex_sig),
         {:ok, parsed} <- parse_payload(raw_body) do
      event_type = Map.get(parsed, "event_type", "unknown")

      insert_attrs = %{
        workspace_id: workspace_id,
        event_type: event_type,
        payload: parsed,
        source_ip: source_ip,
        signature_valid: true,
        handler_result: "processed",
        received_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      case inbound_webhook_repository.insert(insert_attrs, opts) do
        {:ok, inbound} ->
          emit_event(inbound, workspace_id, event_bus, event_bus_opts)
          {:ok, inbound}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp validate_signature_present(nil), do: {:error, :missing_signature}
  defp validate_signature_present(""), do: {:error, :missing_signature}
  defp validate_signature_present(_), do: :ok

  defp verify_signature(payload, secret, hex_sig) do
    if SignaturePolicy.verify(payload, secret, hex_sig) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp parse_payload(raw_body) do
    case Jason.decode(raw_body) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, _} -> {:error, :invalid_payload}
    end
  end

  defp emit_event(inbound, workspace_id, event_bus, event_bus_opts) do
    event =
      InboundWebhookReceived.new(%{
        aggregate_id: inbound.id,
        actor_id: "system",
        workspace_id: workspace_id,
        event_type_received: inbound.event_type,
        signature_valid: inbound.signature_valid,
        source_ip: inbound.source_ip
      })

    event_bus.emit(event, event_bus_opts)
  end
end
