defmodule Jarga.Documents.Domain.Events.DocumentCreatedTest do
  use ExUnit.Case, async: true

  alias Jarga.Documents.Domain.Events.DocumentCreated

  @valid_attrs %{
    aggregate_id: "doc-123",
    actor_id: "user-123",
    document_id: "doc-123",
    workspace_id: "ws-123",
    project_id: "proj-123",
    user_id: "user-123",
    title: "My Document"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert DocumentCreated.event_type() == "documents.document_created"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert DocumentCreated.aggregate_type() == "document"
    end
  end

  describe "new/1" do
    test "creates event with all required fields" do
      event = DocumentCreated.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "documents.document_created"
      assert event.aggregate_type == "document"
      assert event.document_id == "doc-123"
      assert event.workspace_id == "ws-123"
      assert event.project_id == "proj-123"
      assert event.user_id == "user-123"
      assert event.title == "My Document"
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        DocumentCreated.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end

    test "raises when title is missing" do
      assert_raise ArgumentError, fn ->
        DocumentCreated.new(%{
          aggregate_id: "d-1",
          actor_id: "u-1",
          document_id: "d-1",
          workspace_id: "ws-1",
          project_id: "p-1",
          user_id: "u-1"
        })
      end
    end
  end
end
