defmodule Webhooks.Application.UseCases.RetryDelivery do
  @moduledoc """
  Use case for retrying a failed webhook delivery.

  Steps:
  1. Get subscription for the delivery
  2. Re-dispatch HTTP POST with HMAC signature
  3. On success: update status to "success", clear next_retry_at
  4. On failure: check RetryPolicy.should_retry?
     - If yes: schedule next retry
     - If no: mark as "failed"
  """

  @behaviour Webhooks.Application.UseCases.UseCase

  alias Webhooks.Domain.Policies.HmacPolicy
  alias Webhooks.Domain.Policies.RetryPolicy

  @default_subscription_repository Webhooks.Infrastructure.Repositories.SubscriptionRepository
  @default_delivery_repository Webhooks.Infrastructure.Repositories.DeliveryRepository
  @default_http_dispatcher Webhooks.Infrastructure.Services.HttpDispatcher

  @impl true
  def execute(params, opts \\ []) do
    %{delivery: delivery} = params

    subscription_repository =
      Keyword.get(opts, :subscription_repository, @default_subscription_repository)

    delivery_repository =
      Keyword.get(opts, :delivery_repository, @default_delivery_repository)

    http_dispatcher =
      Keyword.get(opts, :http_dispatcher, @default_http_dispatcher)

    repo = Keyword.get(opts, :repo, nil)

    with {:ok, subscription} <-
           subscription_repository.get_by_id(delivery.subscription_id, nil, repo) do
      payload_json = Jason.encode!(delivery.payload)
      signature = HmacPolicy.compute_signature(subscription.secret, payload_json)

      headers = [
        {"content-type", "application/json"},
        {"x-webhook-signature", signature}
      ]

      result = http_dispatcher.dispatch(subscription.url, payload_json, headers)
      new_attempts = delivery.attempts + 1

      update_attrs = build_update_attrs(delivery, new_attempts, result)
      delivery_repository.update_status(delivery.id, update_attrs, repo)
    end
  end

  defp build_update_attrs(delivery, new_attempts, {:ok, status_code, _response_body})
       when status_code >= 200 and status_code < 300 do
    %{
      subscription_id: delivery.subscription_id,
      event_type: delivery.event_type,
      status: "success",
      response_code: status_code,
      attempts: new_attempts,
      next_retry_at: nil
    }
  end

  defp build_update_attrs(delivery, new_attempts, {:ok, status_code, _response_body}) do
    build_failure_attrs(delivery, new_attempts, status_code)
  end

  defp build_update_attrs(delivery, new_attempts, {:error, _reason}) do
    build_failure_attrs(delivery, new_attempts, nil)
  end

  defp build_failure_attrs(delivery, new_attempts, response_code) do
    if RetryPolicy.should_retry?(new_attempts) do
      delay_seconds = RetryPolicy.next_retry_delay_seconds(new_attempts)
      next_retry = DateTime.add(DateTime.utc_now(), delay_seconds, :second)

      %{
        subscription_id: delivery.subscription_id,
        event_type: delivery.event_type,
        status: "pending",
        response_code: response_code,
        attempts: new_attempts,
        next_retry_at: next_retry
      }
    else
      %{
        subscription_id: delivery.subscription_id,
        event_type: delivery.event_type,
        status: "failed",
        response_code: response_code,
        attempts: new_attempts,
        next_retry_at: nil
      }
    end
  end
end
