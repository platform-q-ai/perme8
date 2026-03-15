defmodule Chat.Infrastructure.Subscribers.IdentityEventSubscriberTest do
  use Chat.DataCase

  alias Chat.Infrastructure.Subscribers.IdentityEventSubscriber
  alias Chat.Infrastructure.Schemas.SessionSchema
  alias Identity.Domain.Events.MemberRemoved

  describe "subscriptions/0" do
    test "subscribes to identity workspace_member events" do
      assert IdentityEventSubscriber.subscriptions() == ["events:identity:workspace_member"]
    end
  end

  describe "handle_event/1 with MemberRemoved" do
    test "deletes chat sessions for the removed user in that workspace" do
      user_id = Ecto.UUID.generate()
      workspace_id = Ecto.UUID.generate()
      other_workspace_id = Ecto.UUID.generate()

      # Create sessions in the target workspace
      insert_session(%{user_id: user_id, workspace_id: workspace_id})
      insert_session(%{user_id: user_id, workspace_id: workspace_id})
      # Session in a different workspace (should NOT be deleted)
      keep_session = insert_session(%{user_id: user_id, workspace_id: other_workspace_id})

      event =
        MemberRemoved.new(%{
          aggregate_id: workspace_id,
          actor_id: Ecto.UUID.generate(),
          workspace_id: workspace_id,
          target_user_id: user_id
        })

      assert :ok = IdentityEventSubscriber.handle_event(event)

      # Sessions in target workspace should be deleted
      remaining = Repo.all(from(s in SessionSchema, where: s.user_id == ^user_id))
      assert length(remaining) == 1
      assert hd(remaining).id == keep_session.id
    end

    test "returns :ok when user has no sessions in the workspace" do
      user_id = Ecto.UUID.generate()
      workspace_id = Ecto.UUID.generate()

      event =
        MemberRemoved.new(%{
          aggregate_id: workspace_id,
          actor_id: Ecto.UUID.generate(),
          workspace_id: workspace_id,
          target_user_id: user_id
        })

      assert :ok = IdentityEventSubscriber.handle_event(event)
    end
  end

  describe "handle_event/1 with unknown events" do
    test "returns :ok for unrecognized event structs" do
      assert :ok = IdentityEventSubscriber.handle_event(%{event_type: "unknown.event"})
    end
  end

  defp insert_session(attrs) do
    base = %{user_id: Ecto.UUID.generate(), title: "Session"}

    %SessionSchema{}
    |> SessionSchema.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end
end
