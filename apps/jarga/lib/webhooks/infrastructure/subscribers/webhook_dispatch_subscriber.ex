defmodule Jarga.Webhooks.Infrastructure.Subscribers.WebhookDispatchSubscriber do
  @moduledoc """
  EventHandler that listens for domain events across all contexts
  and dispatches outbound webhook deliveries to matching subscriptions.

  Subscribes to broad context-level topics. When an event arrives with
  a `workspace_id` and `event_type`, queries for active webhook subscriptions
  and dispatches deliveries via the DispatchWebhookDelivery use case.
  """

  use Perme8.Events.EventHandler

  alias Jarga.Webhooks.Infrastructure.Repositories.WebhookRepository
  alias Jarga.Webhooks.Application.UseCases.DispatchWebhookDelivery

  @event_topics [
    "events:identity",
    "events:projects",
    "events:documents",
    "events:chat",
    "events:notifications",
    "events:agents",
    "events:entity_relationship_manager"
  ]

  @impl Perme8.Events.EventHandler
  def subscriptions, do: @event_topics

  @impl Perme8.Events.EventHandler
  def handle_event(%{workspace_id: workspace_id, event_type: event_type} = event)
      when is_binary(workspace_id) and is_binary(event_type) do
    subscriptions = WebhookRepository.list_active_for_event(workspace_id, event_type)

    payload = build_payload(event)

    errors =
      Enum.reduce(subscriptions, [], fn sub, acc ->
        case DispatchWebhookDelivery.execute(%{
               subscription: sub,
               event_type: event_type,
               payload: payload
             }) do
          {:ok, _delivery} ->
            acc

          {:error, reason} ->
            Logger.warning(
              "[WebhookDispatchSubscriber] Failed to dispatch to #{sub.url}: #{inspect(reason)}"
            )

            [{sub.id, reason} | acc]
        end
      end)

    case errors do
      [] -> :ok
      _ -> {:error, {:partial_dispatch_failures, errors}}
    end
  end

  @impl Perme8.Events.EventHandler
  def handle_event(_event), do: :ok

  defp build_payload(event) do
    event
    |> Map.from_struct()
    |> Map.drop([:__struct__])
    |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
  end
end
