defmodule Jarga.Webhooks.Application.UseCases.DispatchWebhookDelivery do
  @moduledoc """
  Use case for dispatching a webhook delivery to a subscription's URL.

  Signs the payload with HMAC-SHA256, sends HTTP POST, records the delivery,
  and emits a WebhookDeliveryCompleted event.
  """

  alias Jarga.Webhooks.Domain.Events.WebhookDeliveryCompleted
  alias Jarga.Webhooks.Domain.Policies.{SignaturePolicy, DeliveryPolicy}

  @default_http_client Jarga.Webhooks.Infrastructure.Services.HttpClient
  @default_delivery_repository Jarga.Webhooks.Infrastructure.Repositories.DeliveryRepository
  @default_event_bus Perme8.Events.EventBus
  @default_max_attempts 5

  def execute(params, opts \\ []) do
    %{subscription: subscription, event_type: event_type, payload: payload} = params
    max_attempts = Map.get(params, :max_attempts, @default_max_attempts)

    http_client = Keyword.get(opts, :http_client, @default_http_client)
    delivery_repository = Keyword.get(opts, :delivery_repository, @default_delivery_repository)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    event_bus_opts = Keyword.get(opts, :event_bus_opts, [])

    if subscription.is_active do
      payload_json = Jason.encode!(payload)
      signature_header = SignaturePolicy.build_signature_header(payload_json, subscription.secret)

      http_result =
        http_client.post(subscription.url, payload,
          headers: %{"X-Webhook-Signature" => signature_header}
        )

      delivery_attrs =
        build_delivery_attrs(subscription, event_type, payload, http_result, max_attempts)

      case delivery_repository.insert(delivery_attrs, opts) do
        {:ok, delivery} ->
          emit_event(delivery, subscription.workspace_id, event_bus, event_bus_opts)
          {:ok, delivery}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :subscription_inactive}
    end
  end

  defp build_delivery_attrs(subscription, event_type, payload, http_result, max_attempts) do
    base = %{
      webhook_subscription_id: subscription.id,
      event_type: event_type,
      payload: payload,
      attempts: 1,
      max_attempts: max_attempts
    }

    case http_result do
      {:ok, %{status: status, body: body}} when status >= 200 and status < 300 ->
        Map.merge(base, %{
          status: "success",
          response_code: status,
          response_body: truncate_body(body),
          next_retry_at: nil
        })

      {:ok, %{status: status, body: body}} ->
        if DeliveryPolicy.max_retries_exhausted?(1, max_attempts) do
          Map.merge(base, %{
            status: "failed",
            response_code: status,
            response_body: truncate_body(body),
            next_retry_at: nil
          })
        else
          Map.merge(base, %{
            status: "pending",
            response_code: status,
            response_body: truncate_body(body),
            next_retry_at: DeliveryPolicy.next_retry_at(1, DateTime.utc_now())
          })
        end

      {:error, _reason} ->
        if DeliveryPolicy.max_retries_exhausted?(1, max_attempts) do
          Map.merge(base, %{
            status: "failed",
            response_code: nil,
            response_body: nil,
            next_retry_at: nil
          })
        else
          Map.merge(base, %{
            status: "pending",
            response_code: nil,
            response_body: nil,
            next_retry_at: DeliveryPolicy.next_retry_at(1, DateTime.utc_now())
          })
        end
    end
  end

  defp truncate_body(body) when is_binary(body), do: String.slice(body, 0, 10_000)
  defp truncate_body(body), do: inspect(body)

  defp emit_event(delivery, workspace_id, event_bus, event_bus_opts) do
    event =
      WebhookDeliveryCompleted.new(%{
        aggregate_id: delivery.id,
        actor_id: "system",
        workspace_id: workspace_id,
        delivery_id: delivery.id,
        status: delivery.status,
        response_code: delivery.response_code,
        attempts: delivery.attempts
      })

    event_bus.emit(event, event_bus_opts)
  end
end
