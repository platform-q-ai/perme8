defmodule Jarga.Notifications.Application.UseCases.CreateWorkspaceInvitationNotification do
  @moduledoc """
  Creates a workspace invitation notification for a user.
  """

  @default_notification_repository Jarga.Notifications.Infrastructure.Repositories.NotificationRepository
  @default_notifier Jarga.Notifications.Infrastructure.Notifiers.PubSubNotifier

  @doc """
  Creates a workspace invitation notification.

  ## Parameters
    * `:user_id` - The ID of the user receiving the notification
    * `:workspace_id` - The ID of the workspace they're invited to
    * `:workspace_name` - The name of the workspace
    * `:invited_by_name` - The name of the person who sent the invitation
    * `:role` - The role they're being invited as (e.g., "member", "admin")

  ## Options
  - `:notifier` - Module implementing notification broadcasting (default: PubSubNotifier)

  Returns `{:ok, notification}` if successful.
  Returns `{:error, changeset}` if validation fails.

  ## Examples

      iex> execute(%{
      ...>   user_id: user_id,
      ...>   workspace_id: workspace_id,
      ...>   workspace_name: "Acme Corp",
      ...>   invited_by_name: "John Doe",
      ...>   role: "member"
      ...> })
      {:ok, %Notification{}}
  """
  def execute(params, opts \\ []) do
    notification_repository =
      Keyword.get(opts, :notification_repository, @default_notification_repository)

    notifier = Keyword.get(opts, :notifier, @default_notifier)
    user_id = get_param(params, :user_id)

    notification_attrs = %{
      user_id: user_id,
      type: "workspace_invitation",
      title: build_title(params),
      body: build_body(params),
      data: %{
        workspace_id: get_param(params, :workspace_id),
        workspace_name: get_param(params, :workspace_name),
        invited_by_name: get_param(params, :invited_by_name),
        role: get_param(params, :role)
      }
    }

    case notification_repository.create(notification_attrs) do
      {:ok, notification} = result ->
        # Broadcast notification to user via PubSub
        notifier.broadcast_new_notification(user_id, notification)
        result

      error ->
        error
    end
  end

  # Helper to get param from either atom or string key
  defp get_param(params, key) when is_map(params) do
    params[key] || params[to_string(key)]
  end

  defp build_title(params) do
    workspace_name = get_param(params, :workspace_name)
    "Workspace Invitation: #{workspace_name}"
  end

  defp build_body(params) do
    invited_by_name = get_param(params, :invited_by_name)
    workspace_name = get_param(params, :workspace_name)
    role = get_param(params, :role)

    "#{invited_by_name} has invited you to join #{workspace_name} as a #{role}."
  end
end
