defmodule Jarga.Documents.Domain.Events.DocumentDeletedTest do
  use ExUnit.Case, async: true

  alias Jarga.Documents.Domain.Events.DocumentDeleted

  @valid_attrs %{
    aggregate_id: "doc-123",
    actor_id: "user-123",
    document_id: "doc-123",
    workspace_id: "ws-123",
    user_id: "user-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert DocumentDeleted.event_type() == "documents.document_deleted"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert DocumentDeleted.aggregate_type() == "document"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = DocumentDeleted.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "documents.document_deleted"
      assert event.document_id == "doc-123"
      assert event.workspace_id == "ws-123"
      assert event.user_id == "user-123"
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        DocumentDeleted.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
