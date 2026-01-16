defmodule Jarga.Documents.Services.PubSubNotifierTest do
  use ExUnit.Case, async: true

  alias Jarga.Documents.Infrastructure.Notifiers.PubSubNotifier

  describe "notify_document_visibility_changed/1" do
    test "returns :ok for valid inputs" do
      document = %Jarga.Documents.Domain.Entities.Document{
        id: "document-123",
        title: "Test Document",
        slug: "test-document",
        workspace_id: "workspace-456",
        is_public: true
      }

      assert :ok = PubSubNotifier.notify_document_visibility_changed(document)
    end
  end

  describe "notify_document_pinned_changed/1" do
    test "returns :ok for valid inputs" do
      document = %Jarga.Documents.Domain.Entities.Document{
        id: "document-123",
        title: "Test Document",
        slug: "test-document",
        workspace_id: "workspace-456",
        is_pinned: true
      }

      assert :ok = PubSubNotifier.notify_document_pinned_changed(document)
    end
  end

  describe "notify_document_title_changed/1" do
    test "returns :ok for valid inputs" do
      document = %Jarga.Documents.Domain.Entities.Document{
        id: "document-123",
        title: "Test Document",
        slug: "test-document",
        workspace_id: "workspace-456"
      }

      assert :ok = PubSubNotifier.notify_document_title_changed(document)
    end
  end
end
