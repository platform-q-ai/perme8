defmodule Chat.Infrastructure.Subscribers.IdentityEventSubscriber do
  @moduledoc """
  Event handler that subscribes to Identity domain events and cleans up
  chat sessions when workspace membership is revoked.

  Subscribes to `MemberRemoved` events and deletes all chat sessions for
  the removed user in that workspace. This is one layer of the referential
  integrity strategy — the OrphanDetectionWorker provides defense-in-depth.

  Note: Identity does not yet emit `UserDeleted` or `WorkspaceDeleted` events.
  When those events are added, this subscriber should be extended to handle them.
  """

  use Perme8.Events.EventHandler

  require Logger

  alias Identity.Domain.Events.MemberRemoved
  alias Chat.Infrastructure.Queries.Queries
  alias Chat.Repo

  @impl Perme8.Events.EventHandler
  def subscriptions do
    ["events:identity:workspace_member"]
  end

  @impl Perme8.Events.EventHandler
  def handle_event(%MemberRemoved{} = event) do
    user_id = event.target_user_id
    workspace_id = event.workspace_id

    try do
      {deleted_count, _} =
        Queries.sessions_for_user_and_workspace(user_id, workspace_id)
        |> Repo.delete_all()

      if deleted_count > 0 do
        Logger.info(
          "IdentityEventSubscriber: cleaned up #{deleted_count} chat session(s) " <>
            "for user #{user_id} in workspace #{workspace_id} after MemberRemoved"
        )
      end

      :ok
    rescue
      error ->
        Logger.error(
          "IdentityEventSubscriber: failed to clean up sessions " <>
            "for user #{user_id} in workspace #{workspace_id}: #{inspect(error)}"
        )

        :ok
    end
  end

  def handle_event(_event), do: :ok
end
