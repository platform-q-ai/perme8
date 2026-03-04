defmodule Notifications.Infrastructure.Subscribers.DomainEventNotificationSubscriberTest do
  use Notifications.DataCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Notifications.Infrastructure.Repositories.NotificationRepository
  alias Notifications.Infrastructure.Subscribers.DomainEventNotificationSubscriber

  defmodule FakeDomainEvent do
    defstruct [
      :event_type,
      :workspace_id,
      :target_user_id,
      :actor_id,
      :project_id,
      :name,
      :document_id,
      :title
    ]
  end

  describe "subscriptions/0" do
    test "returns topics for key domain aggregates" do
      assert DomainEventNotificationSubscriber.subscriptions() == [
               "events:identity:workspace_member",
               "events:projects:project",
               "events:documents:document"
             ]
    end
  end

  describe "handle_event/1" do
    test "creates target-user notifications for membership events" do
      {:ok, pid} = DomainEventNotificationSubscriber.start_link([])
      Sandbox.allow(Notifications.Repo, self(), pid)
      Sandbox.allow(Identity.Repo, self(), pid)

      user = identity_user_fixture()
      workspace_id = Ecto.UUID.generate()

      send(pid, %FakeDomainEvent{
        event_type: "identity.member_joined",
        workspace_id: workspace_id,
        target_user_id: user.id,
        actor_id: user.id
      })

      send(pid, %FakeDomainEvent{
        event_type: "identity.member_removed",
        workspace_id: workspace_id,
        target_user_id: user.id,
        actor_id: Ecto.UUID.generate()
      })

      :sys.get_state(pid)

      notifications = NotificationRepository.list_by_user(user.id)
      assert Enum.any?(notifications, &(&1.type == "workspace_member_joined"))
      assert Enum.any?(notifications, &(&1.type == "workspace_member_removed"))
    end

    test "creates workspace-scoped notifications for project and document events" do
      {:ok, pid} = DomainEventNotificationSubscriber.start_link([])
      Sandbox.allow(Notifications.Repo, self(), pid)
      Sandbox.allow(Identity.Repo, self(), pid)

      actor = identity_user_fixture()
      recipient = identity_user_fixture()
      workspace_id = create_workspace!()

      add_member!(workspace_id, actor, "owner")
      add_member!(workspace_id, recipient, "member")

      send(pid, %FakeDomainEvent{
        event_type: "projects.project_created",
        workspace_id: workspace_id,
        actor_id: actor.id,
        project_id: Ecto.UUID.generate(),
        name: "Roadmap"
      })

      send(pid, %FakeDomainEvent{
        event_type: "projects.project_updated",
        workspace_id: workspace_id,
        actor_id: actor.id,
        project_id: Ecto.UUID.generate(),
        name: "Roadmap v2"
      })

      send(pid, %FakeDomainEvent{
        event_type: "projects.project_deleted",
        workspace_id: workspace_id,
        actor_id: actor.id,
        project_id: Ecto.UUID.generate()
      })

      send(pid, %FakeDomainEvent{
        event_type: "projects.project_archived",
        workspace_id: workspace_id,
        actor_id: actor.id,
        project_id: Ecto.UUID.generate()
      })

      send(pid, %FakeDomainEvent{
        event_type: "documents.document_created",
        workspace_id: workspace_id,
        actor_id: actor.id,
        document_id: Ecto.UUID.generate(),
        title: "Specs"
      })

      send(pid, %FakeDomainEvent{
        event_type: "documents.document_title_changed",
        workspace_id: workspace_id,
        actor_id: actor.id,
        document_id: Ecto.UUID.generate(),
        title: "Specs v2"
      })

      send(pid, %FakeDomainEvent{
        event_type: "documents.document_deleted",
        workspace_id: workspace_id,
        actor_id: actor.id,
        document_id: Ecto.UUID.generate()
      })

      :sys.get_state(pid)

      recipient_types =
        recipient.id
        |> NotificationRepository.list_by_user()
        |> Enum.map(& &1.type)

      assert "project_created" in recipient_types
      assert "project_updated" in recipient_types
      assert "project_deleted" in recipient_types
      assert "project_archived" in recipient_types
      assert "document_created" in recipient_types
      assert "document_updated" in recipient_types
      assert "document_deleted" in recipient_types

      actor_types =
        actor.id
        |> NotificationRepository.list_by_user()
        |> Enum.map(& &1.type)

      refute "project_created" in actor_types
      refute "document_created" in actor_types
    end

    test "ignores unmapped events" do
      {:ok, pid} = DomainEventNotificationSubscriber.start_link([])
      Sandbox.allow(Notifications.Repo, self(), pid)
      Sandbox.allow(Identity.Repo, self(), pid)

      user = identity_user_fixture()

      send(pid, %FakeDomainEvent{
        event_type: "identity.workspace_updated",
        workspace_id: Ecto.UUID.generate(),
        target_user_id: user.id
      })

      :sys.get_state(pid)

      assert NotificationRepository.list_by_user(user.id) == []
    end
  end

  defp create_workspace! do
    id = Ecto.UUID.generate()
    slug = "ws-#{System.unique_integer([:positive])}"
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Identity.Repo.query!(
      """
      INSERT INTO workspaces (id, name, slug, description, color, is_archived, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, false, $6, $6)
      """,
      [Ecto.UUID.dump!(id), "Test Workspace", slug, "Test workspace", "#4A90E2", now]
    )

    id
  end

  defp add_member!(workspace_id, user, role) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Identity.Repo.query!(
      """
      INSERT INTO workspace_members
        (id, workspace_id, user_id, email, role, invited_at, joined_at, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, $6, $6, $6)
      """,
      [
        Ecto.UUID.dump!(Ecto.UUID.generate()),
        Ecto.UUID.dump!(workspace_id),
        Ecto.UUID.dump!(user.id),
        user.email,
        role,
        now
      ]
    )

    :ok
  end

  defp identity_user_fixture do
    id = Ecto.UUID.generate()
    email = "user#{System.unique_integer([:positive])}@example.com"
    now_utc = DateTime.utc_now() |> DateTime.truncate(:second)
    now_naive = DateTime.to_naive(now_utc)

    Identity.Repo.query!(
      """
      INSERT INTO users (id, email, first_name, last_name, confirmed_at, date_created)
      VALUES ($1, $2, $3, $4, $5, $6)
      """,
      [Ecto.UUID.dump!(id), email, "Test", "User", now_utc, now_naive]
    )

    %{id: id, email: email}
  end
end
