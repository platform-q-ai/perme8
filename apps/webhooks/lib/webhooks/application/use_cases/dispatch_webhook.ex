defmodule Webhooks.Application.UseCases.DispatchWebhook do
  @moduledoc """
  Use case for dispatching outbound webhook HTTP POST requests.

  Called by the EventHandler (not by users), so no authorization is required.

  For each matching active subscription:
  1. Builds JSON payload
  2. Computes HMAC-SHA256 signature
  3. Dispatches HTTP POST
  4. Records delivery result (success or schedules retry)
  """

  @behaviour Webhooks.Application.UseCases.UseCase

  alias Webhooks.Domain.Policies.HmacPolicy
  alias Webhooks.Domain.Policies.RetryPolicy

  @default_subscription_repository Webhooks.Infrastructure.Repositories.SubscriptionRepository
  @default_delivery_repository Webhooks.Infrastructure.Repositories.DeliveryRepository
  @default_http_dispatcher Webhooks.Infrastructure.Services.HttpDispatcher

  @impl true
  def execute(params, opts \\ []) do
    %{
      workspace_id: workspace_id,
      event_type: event_type,
      payload: payload
    } = params

    subscription_repository =
      Keyword.get(opts, :subscription_repository, @default_subscription_repository)

    delivery_repository =
      Keyword.get(opts, :delivery_repository, @default_delivery_repository)

    http_dispatcher =
      Keyword.get(opts, :http_dispatcher, @default_http_dispatcher)

    repo = Keyword.get(opts, :repo, nil)

    with {:ok, subscriptions} <-
           subscription_repository.list_active_for_event_type(workspace_id, event_type, repo) do
      deliveries =
        Enum.map(subscriptions, fn subscription ->
          dispatch_to_subscription(
            subscription,
            event_type,
            payload,
            http_dispatcher,
            delivery_repository,
            repo
          )
        end)

      {:ok, deliveries}
    end
  end

  defp dispatch_to_subscription(
         subscription,
         event_type,
         payload,
         http_dispatcher,
         delivery_repository,
         repo
       ) do
    payload_json = Jason.encode!(payload)
    signature = HmacPolicy.compute_signature(subscription.secret, payload_json)

    headers = [
      {"content-type", "application/json"},
      {"x-webhook-signature", signature}
    ]

    result = http_dispatcher.dispatch(subscription.url, payload_json, headers)

    delivery_attrs = build_delivery_attrs(subscription, event_type, payload, result)
    {:ok, delivery} = delivery_repository.insert(delivery_attrs, repo)
    delivery
  end

  defp build_delivery_attrs(subscription, event_type, payload, {:ok, status_code, response_body}) do
    if status_code >= 200 and status_code < 300 do
      %{
        subscription_id: subscription.id,
        event_type: event_type,
        payload: payload,
        status: "success",
        response_code: status_code,
        response_body: response_body,
        attempts: 1,
        next_retry_at: nil
      }
    else
      %{
        subscription_id: subscription.id,
        event_type: event_type,
        payload: payload,
        status: "pending",
        response_code: status_code,
        response_body: response_body,
        attempts: 1,
        next_retry_at: compute_next_retry(1)
      }
    end
  end

  defp build_delivery_attrs(subscription, event_type, payload, {:error, _reason}) do
    %{
      subscription_id: subscription.id,
      event_type: event_type,
      payload: payload,
      status: "pending",
      response_code: nil,
      response_body: nil,
      attempts: 1,
      next_retry_at: compute_next_retry(1)
    }
  end

  defp compute_next_retry(attempts) do
    if RetryPolicy.should_retry?(attempts) do
      delay_seconds = RetryPolicy.next_retry_delay_seconds(attempts)
      DateTime.add(DateTime.utc_now(), delay_seconds, :second)
    else
      nil
    end
  end
end
