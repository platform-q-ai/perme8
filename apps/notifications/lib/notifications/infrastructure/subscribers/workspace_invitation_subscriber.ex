defmodule Notifications.Infrastructure.Subscribers.WorkspaceInvitationSubscriber do
  @moduledoc """
  EventHandler that listens for workspace invitation events
  and creates corresponding notifications.

  Subscribes to identity context events and reacts to MemberInvited
  events by creating notifications via the CreateNotification use case.
  """

  use Perme8.Events.EventHandler

  alias Identity.Domain.Events.MemberInvited

  @create_notification_use_case Notifications.Application.UseCases.CreateNotification

  @impl Perme8.Events.EventHandler
  def subscriptions do
    # Subscribe to the aggregate-scoped topic only to avoid duplicate delivery.
    # The EventBus broadcasts to both "events:identity" and
    # "events:identity:workspace_member" — subscribing to both would cause
    # handle_event/1 to fire twice for the same event.
    ["events:identity:workspace_member"]
  end

  @impl Perme8.Events.EventHandler
  def handle_event(%MemberInvited{} = event) do
    params = %{
      user_id: event.user_id,
      type: "workspace_invitation",
      data: %{
        workspace_id: event.workspace_id,
        workspace_name: event.workspace_name,
        invited_by_name: event.invited_by_name,
        role: event.role
      }
    }

    case @create_notification_use_case.execute(params) do
      {:ok, _notification} ->
        Logger.debug("Created notification for workspace invitation: #{event.workspace_id}")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Perme8.Events.EventHandler
  def handle_event(_event), do: :ok
end
