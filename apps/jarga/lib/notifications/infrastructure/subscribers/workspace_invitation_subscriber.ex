defmodule Jarga.Notifications.Infrastructure.Subscribers.WorkspaceInvitationSubscriber do
  @moduledoc """
  PubSub subscriber that listens for workspace invitation events
  and creates corresponding notifications.

  This decouples the Notifications context from the Workspaces context
  by using event-driven communication instead of direct function calls.
  """

  use GenServer
  require Logger

  @default_create_notification_use_case Jarga.Notifications.Application.UseCases.CreateWorkspaceInvitationNotification

  def start_link(opts \\ []) do
    use_case =
      Keyword.get(opts, :create_notification_use_case, @default_create_notification_use_case)

    GenServer.start_link(__MODULE__, %{use_case: use_case}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    # Subscribe to workspace invitation events
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace_invitations")
    {:ok, state}
  end

  @impl true
  def handle_info({:workspace_invitation_created, params}, %{use_case: use_case} = state) do
    # Create notification when a workspace invitation event is received
    case use_case.execute(params) do
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
