defmodule Jarga.Documents.Application.UseCases.UpdateDocumentTest do
  use Jarga.DataCase, async: false

  alias Jarga.Documents.Application.UseCases.UpdateDocument

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.DocumentsFixtures

  # Test notifier for testing notifications without actual PubSub
  defmodule TestNotifier do
    @behaviour Jarga.Documents.Application.Services.NotificationService

    def notify_document_visibility_changed(_document), do: send(self(), :visibility_notified)
    def notify_document_pinned_changed(_document), do: send(self(), :pinned_notified)
    def notify_document_title_changed(_document), do: send(self(), :title_notified)
    def notify_document_created(_document), do: send(self(), :created_notified)
    def notify_document_deleted(_document), do: send(self(), :deleted_notified)
  end

  describe "execute/2 - successful document updates" do
    test "owner can update their own document" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      document = document_fixture(owner, workspace, nil, %{})

      params = %{
        actor: owner,
        document_id: document.id,
        attrs: %{title: "Updated Title"}
      }

      assert {:ok, updated} = UpdateDocument.execute(params)
      assert updated.title == "Updated Title"
    end

    test "member can edit public documents they don't own" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      document = document_fixture(owner, workspace, nil, %{is_public: true})

      params = %{
        actor: member,
        document_id: document.id,
        attrs: %{title: "Member Updated"}
      }

      assert {:ok, updated} = UpdateDocument.execute(params)
      assert updated.title == "Member Updated"
    end

    test "admin can edit public documents" do
      owner = user_fixture()
      admin = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, admin.email, :admin)

      document = document_fixture(owner, workspace, nil, %{is_public: true})

      params = %{
        actor: admin,
        document_id: document.id,
        attrs: %{title: "Admin Updated"}
      }

      assert {:ok, updated} = UpdateDocument.execute(params)
      assert updated.title == "Admin Updated"
    end

    test "member can pin public documents" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      document = document_fixture(owner, workspace, nil, %{is_public: true})

      params = %{
        actor: member,
        document_id: document.id,
        attrs: %{is_pinned: true}
      }

      assert {:ok, updated} = UpdateDocument.execute(params)
      assert updated.is_pinned == true
    end

    test "owner can pin their own document" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      document = document_fixture(owner, workspace, nil, %{is_pinned: false})

      params = %{
        actor: owner,
        document_id: document.id,
        attrs: %{is_pinned: true}
      }

      assert {:ok, updated} = UpdateDocument.execute(params)
      assert updated.is_pinned == true
    end

    test "owner can change document visibility" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      document = document_fixture(owner, workspace, nil, %{is_public: false})

      params = %{
        actor: owner,
        document_id: document.id,
        attrs: %{is_public: true}
      }

      assert {:ok, updated} = UpdateDocument.execute(params)
      assert updated.is_public == true
    end
  end

  describe "execute/2 - authorization failures" do
    test "member cannot edit private documents they don't own" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      document = document_fixture(owner, workspace, nil, %{is_public: false})

      params = %{
        actor: member,
        document_id: document.id,
        attrs: %{title: "Hacked"}
      }

      assert {:error, :forbidden} = UpdateDocument.execute(params)
    end

    test "admin cannot edit private documents they don't own" do
      owner = user_fixture()
      admin = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, admin.email, :admin)

      document = document_fixture(owner, workspace, nil, %{is_public: false})

      params = %{
        actor: admin,
        document_id: document.id,
        attrs: %{title: "Admin Hacked"}
      }

      assert {:error, :forbidden} = UpdateDocument.execute(params)
    end

    test "member cannot pin private documents they don't own" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      document = document_fixture(owner, workspace, nil, %{is_public: false})

      params = %{
        actor: member,
        document_id: document.id,
        attrs: %{is_pinned: true}
      }

      assert {:error, :forbidden} = UpdateDocument.execute(params)
    end

    test "guest cannot edit any documents" do
      owner = user_fixture()
      guest = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, guest.email, :guest)

      document = document_fixture(owner, workspace, nil, %{is_public: true})

      params = %{
        actor: guest,
        document_id: document.id,
        attrs: %{title: "Guest Update"}
      }

      assert {:error, :forbidden} = UpdateDocument.execute(params)
    end

    test "guest cannot pin documents" do
      owner = user_fixture()
      guest = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, guest.email, :guest)

      document = document_fixture(owner, workspace, nil, %{is_public: true})

      params = %{
        actor: guest,
        document_id: document.id,
        attrs: %{is_pinned: true}
      }

      assert {:error, :forbidden} = UpdateDocument.execute(params)
    end

    test "non-member cannot update documents" do
      owner = user_fixture()
      non_member = user_fixture()
      workspace = workspace_fixture(owner)
      document = document_fixture(owner, workspace, nil, %{is_public: true})

      params = %{
        actor: non_member,
        document_id: document.id,
        attrs: %{title: "Outsider Update"}
      }

      assert {:error, reason} = UpdateDocument.execute(params)
      assert reason in [:workspace_not_found, :unauthorized]
    end

    test "returns error when document doesn't exist" do
      owner = user_fixture()
      _workspace = workspace_fixture(owner)
      fake_document_id = Ecto.UUID.generate()

      params = %{
        actor: owner,
        document_id: fake_document_id,
        attrs: %{title: "Update"}
      }

      assert {:error, :document_not_found} = UpdateDocument.execute(params)
    end

    test "returns error when user cannot access private document" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      document = document_fixture(owner, workspace, nil, %{is_public: false})

      params = %{
        actor: member,
        document_id: document.id,
        attrs: %{title: "Update"}
      }

      assert {:error, :forbidden} = UpdateDocument.execute(params)
    end
  end

  describe "execute/2 - event emission" do
    # Mock notifier that does nothing (for event tests)
    defmodule EventTestNotifier do
      @behaviour Jarga.Documents.Application.Services.NotificationService
      def notify_document_created(_document), do: :ok
      def notify_document_deleted(_document), do: :ok
      def notify_document_title_changed(_document), do: :ok
      def notify_document_visibility_changed(_document), do: :ok
      def notify_document_pinned_changed(_document), do: :ok
    end

    test "emits DocumentTitleChanged event when title changes" do
      ensure_test_event_bus_started()

      owner = user_fixture()
      workspace = workspace_fixture(owner)
      document = document_fixture(owner, workspace, nil, %{})

      params = %{
        actor: owner,
        document_id: document.id,
        attrs: %{title: "New Title"}
      }

      opts = [notifier: EventTestNotifier, event_bus: Perme8.Events.TestEventBus]

      assert {:ok, _updated} = UpdateDocument.execute(params, opts)

      events = Perme8.Events.TestEventBus.get_events()
      assert [%Jarga.Documents.Domain.Events.DocumentTitleChanged{} = event] = events
      assert event.document_id == document.id
      assert event.workspace_id == document.workspace_id
      assert event.title == "New Title"
      assert event.user_id == owner.id
    end

    test "emits DocumentVisibilityChanged event when is_public changes" do
      ensure_test_event_bus_started()

      owner = user_fixture()
      workspace = workspace_fixture(owner)
      document = document_fixture(owner, workspace, nil, %{is_public: false})

      params = %{
        actor: owner,
        document_id: document.id,
        attrs: %{is_public: true}
      }

      opts = [notifier: EventTestNotifier, event_bus: Perme8.Events.TestEventBus]

      assert {:ok, _updated} = UpdateDocument.execute(params, opts)

      events = Perme8.Events.TestEventBus.get_events()
      assert [%Jarga.Documents.Domain.Events.DocumentVisibilityChanged{} = event] = events
      assert event.document_id == document.id
      assert event.is_public == true
    end

    test "emits DocumentPinnedChanged event when is_pinned changes" do
      ensure_test_event_bus_started()

      owner = user_fixture()
      workspace = workspace_fixture(owner)
      document = document_fixture(owner, workspace, nil, %{is_pinned: false})

      params = %{
        actor: owner,
        document_id: document.id,
        attrs: %{is_pinned: true}
      }

      opts = [notifier: EventTestNotifier, event_bus: Perme8.Events.TestEventBus]

      assert {:ok, _updated} = UpdateDocument.execute(params, opts)

      events = Perme8.Events.TestEventBus.get_events()
      assert [%Jarga.Documents.Domain.Events.DocumentPinnedChanged{} = event] = events
      assert event.document_id == document.id
      assert event.is_pinned == true
    end

    test "does not emit events when no relevant fields change" do
      ensure_test_event_bus_started()

      owner = user_fixture()
      workspace = workspace_fixture(owner)
      document = document_fixture(owner, workspace, nil, %{})

      params = %{
        actor: owner,
        document_id: document.id,
        attrs: %{title: document.title}
      }

      opts = [notifier: EventTestNotifier, event_bus: Perme8.Events.TestEventBus]

      assert {:ok, _updated} = UpdateDocument.execute(params, opts)
      assert [] = Perme8.Events.TestEventBus.get_events()
    end

    test "emits multiple events when multiple fields change" do
      ensure_test_event_bus_started()

      owner = user_fixture()
      workspace = workspace_fixture(owner)
      document = document_fixture(owner, workspace, nil, %{is_public: false, is_pinned: false})

      params = %{
        actor: owner,
        document_id: document.id,
        attrs: %{title: "New Title", is_public: true}
      }

      opts = [notifier: EventTestNotifier, event_bus: Perme8.Events.TestEventBus]

      assert {:ok, _updated} = UpdateDocument.execute(params, opts)

      events = Perme8.Events.TestEventBus.get_events()
      assert length(events) == 2

      event_types = Enum.map(events, & &1.__struct__)
      assert Jarga.Documents.Domain.Events.DocumentVisibilityChanged in event_types
      assert Jarga.Documents.Domain.Events.DocumentTitleChanged in event_types
    end
  end

  describe "execute/2 - validation failures" do
    test "returns error with invalid attributes" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      document = document_fixture(owner, workspace, nil, %{})

      params = %{
        actor: owner,
        document_id: document.id,
        attrs: %{title: ""}
      }

      assert {:error, %Ecto.Changeset{}} = UpdateDocument.execute(params)
    end
  end

  describe "execute/2 - notifications" do
    setup do
      {:ok, notifier: TestNotifier}
    end

    test "sends notification when visibility changes", %{notifier: notifier} do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      document = document_fixture(owner, workspace, nil, %{is_public: false})

      params = %{
        actor: owner,
        document_id: document.id,
        attrs: %{is_public: true}
      }

      assert {:ok, _updated} = UpdateDocument.execute(params, notifier: notifier)
      assert_received :visibility_notified
    end

    test "sends notification when pin status changes", %{notifier: notifier} do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      document = document_fixture(owner, workspace, nil, %{is_pinned: false})

      params = %{
        actor: owner,
        document_id: document.id,
        attrs: %{is_pinned: true}
      }

      assert {:ok, _updated} = UpdateDocument.execute(params, notifier: notifier)
      assert_received :pinned_notified
    end

    test "sends notification when title changes", %{notifier: notifier} do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      document = document_fixture(owner, workspace, nil, %{})

      params = %{
        actor: owner,
        document_id: document.id,
        attrs: %{title: "New Title"}
      }

      assert {:ok, _updated} = UpdateDocument.execute(params, notifier: notifier)
      assert_received :title_notified
    end
  end

  defp ensure_test_event_bus_started do
    case Process.whereis(Perme8.Events.TestEventBus) do
      nil ->
        {:ok, _pid} = Perme8.Events.TestEventBus.start_link([])
        :ok

      _pid ->
        Perme8.Events.TestEventBus.reset()
    end
  end
end
