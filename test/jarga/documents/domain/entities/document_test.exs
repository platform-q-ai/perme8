defmodule Jarga.Documents.Domain.Entities.DocumentTest do
  use ExUnit.Case, async: true

  alias Jarga.Documents.Domain.Entities.Document

  describe "new/1" do
    test "creates a document with given attributes" do
      attrs = %{
        id: "doc-123",
        title: "Test Document",
        slug: "test-document",
        user_id: "user-456",
        workspace_id: "ws-789",
        created_by: "user-456"
      }

      document = Document.new(attrs)

      assert document.id == "doc-123"
      assert document.title == "Test Document"
      assert document.slug == "test-document"
      assert document.user_id == "user-456"
      assert document.workspace_id == "ws-789"
      assert document.created_by == "user-456"
      assert document.is_public == false
      assert document.is_pinned == false
      assert document.document_components == []
    end

    test "sets default values for optional fields" do
      attrs = %{
        title: "Test",
        slug: "test",
        user_id: "user-1",
        workspace_id: "ws-1",
        created_by: "user-1"
      }

      document = Document.new(attrs)

      assert document.is_public == false
      assert document.is_pinned == false
      assert document.document_components == []
    end

    test "allows overriding default values" do
      attrs = %{
        title: "Test",
        slug: "test",
        user_id: "user-1",
        workspace_id: "ws-1",
        created_by: "user-1",
        is_public: true,
        is_pinned: true
      }

      document = Document.new(attrs)

      assert document.is_public == true
      assert document.is_pinned == true
    end
  end

  describe "from_schema/1" do
    test "converts a schema to a domain entity" do
      schema = %{
        __struct__: SomeSchema,
        id: "doc-123",
        title: "Test Document",
        slug: "test-document",
        is_public: true,
        is_pinned: false,
        user_id: "user-456",
        workspace_id: "ws-789",
        project_id: "proj-101",
        created_by: "user-456",
        document_components: [],
        inserted_at: ~U[2025-01-01 00:00:00Z],
        updated_at: ~U[2025-01-01 00:00:00Z]
      }

      document = Document.from_schema(schema)

      assert %Document{} = document
      assert document.id == "doc-123"
      assert document.title == "Test Document"
      assert document.slug == "test-document"
      assert document.is_public == true
      assert document.is_pinned == false
      assert document.user_id == "user-456"
      assert document.workspace_id == "ws-789"
      assert document.project_id == "proj-101"
      assert document.created_by == "user-456"
      assert document.document_components == []
      assert document.inserted_at == ~U[2025-01-01 00:00:00Z]
      assert document.updated_at == ~U[2025-01-01 00:00:00Z]
    end

    test "handles nil document_components" do
      schema = %{
        __struct__: SomeSchema,
        id: "doc-123",
        title: "Test",
        slug: "test",
        is_public: false,
        is_pinned: false,
        user_id: "user-1",
        workspace_id: "ws-1",
        project_id: nil,
        created_by: "user-1",
        document_components: nil,
        inserted_at: ~U[2025-01-01 00:00:00Z],
        updated_at: ~U[2025-01-01 00:00:00Z]
      }

      document = Document.from_schema(schema)

      assert document.document_components == []
    end
  end
end
