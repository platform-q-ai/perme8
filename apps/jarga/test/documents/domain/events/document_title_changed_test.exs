defmodule Jarga.Documents.Domain.Events.DocumentTitleChangedTest do
  use ExUnit.Case, async: true

  alias Jarga.Documents.Domain.Events.DocumentTitleChanged

  @valid_attrs %{
    aggregate_id: "doc-123",
    actor_id: "user-123",
    document_id: "doc-123",
    workspace_id: "ws-123",
    user_id: "user-123",
    title: "New Title"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert DocumentTitleChanged.event_type() == "documents.document_title_changed"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert DocumentTitleChanged.aggregate_type() == "document"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = DocumentTitleChanged.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "documents.document_title_changed"
      assert event.document_id == "doc-123"
      assert event.workspace_id == "ws-123"
      assert event.user_id == "user-123"
      assert event.title == "New Title"
    end

    test "optional previous_title defaults to nil" do
      event = DocumentTitleChanged.new(@valid_attrs)
      assert event.previous_title == nil
    end

    test "accepts optional previous_title" do
      event = DocumentTitleChanged.new(Map.put(@valid_attrs, :previous_title, "Old Title"))
      assert event.previous_title == "Old Title"
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        DocumentTitleChanged.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
