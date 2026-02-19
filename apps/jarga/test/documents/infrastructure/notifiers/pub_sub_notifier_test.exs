defmodule Jarga.Documents.Services.PubSubNotifierTest do
  use ExUnit.Case, async: true

  alias Jarga.Documents.Infrastructure.Notifiers.PubSubNotifier

  describe "notify_document_visibility_changed/1" do
    test "returns :ok (no-op — EventBus handles delivery now)" do
      document = %Jarga.Documents.Domain.Entities.Document{
        id: "document-123",
        title: "Test Document",
        slug: "test-document",
        workspace_id: "workspace-456",
        is_public: true
      }

      assert :ok = PubSubNotifier.notify_document_visibility_changed(document)
    end

    test "does not broadcast legacy PubSub tuple" do
      document = %Jarga.Documents.Domain.Entities.Document{
        id: "document-123",
        title: "Test Document",
        slug: "test-document",
        workspace_id: "workspace-456",
        is_public: true
      }

      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:workspace-456")
      Phoenix.PubSub.subscribe(Jarga.PubSub, "document:document-123")

      PubSubNotifier.notify_document_visibility_changed(document)

      refute_receive {:document_visibility_changed, _, _}
    end
  end

  describe "notify_document_pinned_changed/1" do
    test "returns :ok (no-op — EventBus handles delivery now)" do
      document = %Jarga.Documents.Domain.Entities.Document{
        id: "document-123",
        title: "Test Document",
        slug: "test-document",
        workspace_id: "workspace-456",
        is_pinned: true
      }

      assert :ok = PubSubNotifier.notify_document_pinned_changed(document)
    end

    test "does not broadcast legacy PubSub tuple" do
      document = %Jarga.Documents.Domain.Entities.Document{
        id: "document-123",
        title: "Test Document",
        slug: "test-document",
        workspace_id: "workspace-456",
        is_pinned: true
      }

      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:workspace-456")
      Phoenix.PubSub.subscribe(Jarga.PubSub, "document:document-123")

      PubSubNotifier.notify_document_pinned_changed(document)

      refute_receive {:document_pinned_changed, _, _}
    end
  end

  describe "notify_document_title_changed/1" do
    test "returns :ok (no-op — EventBus handles delivery now)" do
      document = %Jarga.Documents.Domain.Entities.Document{
        id: "document-123",
        title: "Test Document",
        slug: "test-document",
        workspace_id: "workspace-456"
      }

      assert :ok = PubSubNotifier.notify_document_title_changed(document)
    end

    test "does not broadcast legacy PubSub tuple" do
      document = %Jarga.Documents.Domain.Entities.Document{
        id: "document-123",
        title: "Test Document",
        slug: "test-document",
        workspace_id: "workspace-456"
      }

      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:workspace-456")
      Phoenix.PubSub.subscribe(Jarga.PubSub, "document:document-123")

      PubSubNotifier.notify_document_title_changed(document)

      refute_receive {:document_title_changed, _, _}
    end
  end

  describe "notify_document_created/1" do
    test "returns :ok (no-op — EventBus handles delivery now)" do
      document = %Jarga.Documents.Domain.Entities.Document{
        id: "document-123",
        title: "Test Document",
        slug: "test-document",
        workspace_id: "workspace-456"
      }

      assert :ok = PubSubNotifier.notify_document_created(document)
    end

    test "does not broadcast legacy PubSub tuple" do
      document = %Jarga.Documents.Domain.Entities.Document{
        id: "document-123",
        title: "Test Document",
        slug: "test-document",
        workspace_id: "workspace-456"
      }

      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:workspace-456")

      PubSubNotifier.notify_document_created(document)

      refute_receive {:document_created, _}
    end
  end

  describe "notify_document_deleted/1" do
    test "returns :ok (no-op — EventBus handles delivery now)" do
      document = %Jarga.Documents.Domain.Entities.Document{
        id: "document-123",
        title: "Test Document",
        slug: "test-document",
        workspace_id: "workspace-456"
      }

      assert :ok = PubSubNotifier.notify_document_deleted(document)
    end

    test "does not broadcast legacy PubSub tuple" do
      document = %Jarga.Documents.Domain.Entities.Document{
        id: "document-123",
        title: "Test Document",
        slug: "test-document",
        workspace_id: "workspace-456"
      }

      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:workspace-456")

      PubSubNotifier.notify_document_deleted(document)

      refute_receive {:document_deleted, _}
    end
  end
end
