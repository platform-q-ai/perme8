defmodule Jarga.Documents.Domain.Events.DocumentVisibilityChangedTest do
  use ExUnit.Case, async: true

  alias Jarga.Documents.Domain.Events.DocumentVisibilityChanged

  @valid_attrs %{
    aggregate_id: "doc-123",
    actor_id: "user-123",
    document_id: "doc-123",
    workspace_id: "ws-123",
    user_id: "user-123",
    is_public: true
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert DocumentVisibilityChanged.event_type() == "documents.document_visibility_changed"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert DocumentVisibilityChanged.aggregate_type() == "document"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = DocumentVisibilityChanged.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "documents.document_visibility_changed"
      assert event.document_id == "doc-123"
      assert event.workspace_id == "ws-123"
      assert event.user_id == "user-123"
      assert event.is_public == true
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        DocumentVisibilityChanged.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
