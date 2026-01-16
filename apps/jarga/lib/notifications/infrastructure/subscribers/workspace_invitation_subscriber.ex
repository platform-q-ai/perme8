defmodule Jarga.Notifications.Infrastructure.Subscribers.WorkspaceInvitationSubscriber do
  @moduledoc """
  PubSub subscriber that listens for workspace invitation events
  and creates corresponding notifications.

  This decouples the Notifications context from the Workspaces context
  by using event-driven communication instead of direct function calls.
  """

  use GenServer
  require Logger

  alias Jarga.Notifications

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    # Subscribe to workspace invitation events
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace_invitations")
    {:ok, state}
  end

  @impl true
  def handle_info({:workspace_invitation_created, params}, state) do
    # Create notification when a workspace invitation event is received
    case Notifications.create_workspace_invitation_notification(params) do
      {:ok, _notification} ->
        Logger.debug("Created notification for workspace invitation: #{params.workspace_id}")

      {:error, reason} ->
        Logger.error("Failed to create notification for workspace invitation: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
