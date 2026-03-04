defmodule Notifications.Infrastructure.Subscribers.DomainEventNotificationSubscriber do
  @moduledoc """
  EventHandler that maps key domain events to notifications.
  """

  use Perme8.Events.EventHandler

  alias Notifications.Infrastructure.Subscribers.DomainEventNotificationRegistry

  @create_notification_use_case Notifications.Application.UseCases.CreateNotification

  @impl Perme8.Events.EventHandler
  def subscriptions do
    [
      "events:identity:workspace_member",
      "events:projects:project",
      "events:documents:document"
    ]
  end

  @impl Perme8.Events.EventHandler
  def handle_event(%{event_type: event_type} = event) when is_binary(event_type) do
    case DomainEventNotificationRegistry.mapping_for(event_type) do
      nil ->
        :ok

      mapping ->
        event
        |> recipient_ids(mapping.recipient_strategy)
        |> Enum.reduce_while(:ok, fn recipient_id, _acc ->
          params = %{
            user_id: recipient_id,
            type: mapping.type,
            title: mapping.title,
            body: DomainEventNotificationRegistry.build_body(event_type, event),
            data: DomainEventNotificationRegistry.build_data(event_type, event)
          }

          case @create_notification_use_case.execute(params) do
            {:ok, _notification} -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)
    end
  end

  @impl Perme8.Events.EventHandler
  def handle_event(_event), do: :ok

  defp recipient_ids(event, :target_user) do
    case fetch(event, :target_user_id) do
      user_id when is_binary(user_id) and user_id != "" -> [user_id]
      _ -> []
    end
  end

  defp recipient_ids(event, :workspace_members_except_actor) do
    workspace_id = fetch(event, :workspace_id)
    actor_id = fetch(event, :actor_id)

    if is_binary(workspace_id) and workspace_id != "" do
      workspace_id
      |> Identity.list_members()
      |> Enum.map(& &1.user_id)
      |> Enum.filter(&is_binary/1)
      |> Enum.reject(&(&1 == actor_id))
      |> Enum.uniq()
    else
      []
    end
  end

  defp recipient_ids(_event, _), do: []

  defp fetch(data, key) when is_map(data) do
    Map.get(data, key) || Map.get(data, to_string(key))
  end
end
