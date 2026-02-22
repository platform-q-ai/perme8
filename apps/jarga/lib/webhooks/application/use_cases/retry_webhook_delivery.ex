defmodule Jarga.Webhooks.Application.UseCases.RetryWebhookDelivery do
  @moduledoc """
  Use case for retrying a failed/pending webhook delivery.

  Re-sends the HTTP POST, updates the delivery record, and emits event.
  """

  alias Jarga.Webhooks.Domain.Events.WebhookDeliveryCompleted
  alias Jarga.Webhooks.Domain.Policies.{SignaturePolicy, DeliveryPolicy}

  @default_http_client Jarga.Webhooks.Infrastructure.Services.HttpClient
  @default_delivery_repository Jarga.Webhooks.Infrastructure.Repositories.DeliveryRepository
  @default_webhook_repository Jarga.Webhooks.Infrastructure.Repositories.WebhookRepository
  @default_event_bus Perme8.Events.EventBus

  def execute(params, opts \\ []) do
    %{delivery_id: delivery_id} = params

    http_client = Keyword.get(opts, :http_client, @default_http_client)
    delivery_repository = Keyword.get(opts, :delivery_repository, @default_delivery_repository)
    webhook_repository = Keyword.get(opts, :webhook_repository, @default_webhook_repository)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    event_bus_opts = Keyword.get(opts, :event_bus_opts, [])

    with {:ok, delivery} <- fetch_delivery(delivery_id, delivery_repository, opts),
         :ok <- validate_retryable(delivery),
         {:ok, subscription} <-
           fetch_subscription(delivery.webhook_subscription_id, webhook_repository, opts) do
      payload_json = Jason.encode!(delivery.payload)
      signature_header = SignaturePolicy.build_signature_header(payload_json, subscription.secret)

      http_result =
        http_client.post(subscription.url, delivery.payload,
          headers: %{"X-Webhook-Signature" => signature_header}
        )

      new_attempts = delivery.attempts + 1
      update_attrs = build_update_attrs(http_result, new_attempts, delivery.max_attempts)

      case delivery_repository.update(delivery, update_attrs, opts) do
        {:ok, updated} ->
          emit_event(updated, subscription.workspace_id, event_bus, event_bus_opts)
          {:ok, updated}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp fetch_delivery(id, repo, opts) do
    case repo.get(id, opts) do
      nil -> {:error, :not_found}
      delivery -> {:ok, delivery}
    end
  end

  defp fetch_subscription(id, repo, opts) do
    case repo.get(id, opts) do
      nil -> {:error, :subscription_not_found}
      subscription -> {:ok, subscription}
    end
  end

  defp validate_retryable(%{status: "success"}), do: {:error, :already_succeeded}
  defp validate_retryable(_delivery), do: :ok

  defp build_update_attrs(http_result, attempts, max_attempts) do
    case http_result do
      {:ok, %{status: status, body: body}} when status >= 200 and status < 300 ->
        %{
          status: "success",
          attempts: attempts,
          response_code: status,
          response_body: truncate_body(body),
          next_retry_at: nil
        }

      {:ok, %{status: status, body: body}} ->
        if DeliveryPolicy.max_retries_exhausted?(attempts, max_attempts) do
          %{
            status: "failed",
            attempts: attempts,
            response_code: status,
            response_body: truncate_body(body),
            next_retry_at: nil
          }
        else
          %{
            status: "pending",
            attempts: attempts,
            response_code: status,
            response_body: truncate_body(body),
            next_retry_at: DeliveryPolicy.next_retry_at(attempts, DateTime.utc_now())
          }
        end

      {:error, _reason} ->
        if DeliveryPolicy.max_retries_exhausted?(attempts, max_attempts) do
          %{status: "failed", attempts: attempts, next_retry_at: nil}
        else
          %{
            status: "pending",
            attempts: attempts,
            next_retry_at: DeliveryPolicy.next_retry_at(attempts, DateTime.utc_now())
          }
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
