defmodule Jarga.Pages.Services.PubSubNotifierTest do
  use ExUnit.Case, async: true

  alias Jarga.Pages.Services.PubSubNotifier

  describe "notify_page_visibility_changed/1" do
    test "returns :ok for valid inputs" do
      page = %Jarga.Pages.Page{
        id: "page-123",
        title: "Test Page",
        slug: "test-page",
        workspace_id: "workspace-456",
        is_public: true
      }

      assert :ok = PubSubNotifier.notify_page_visibility_changed(page)
    end
  end

  describe "notify_page_pinned_changed/1" do
    test "returns :ok for valid inputs" do
      page = %Jarga.Pages.Page{
        id: "page-123",
        title: "Test Page",
        slug: "test-page",
        workspace_id: "workspace-456",
        is_pinned: true
      }

      assert :ok = PubSubNotifier.notify_page_pinned_changed(page)
    end
  end

  describe "notify_page_title_changed/1" do
    test "returns :ok for valid inputs" do
      page = %Jarga.Pages.Page{
        id: "page-123",
        title: "Test Page",
        slug: "test-page",
        workspace_id: "workspace-456"
      }

      assert :ok = PubSubNotifier.notify_page_title_changed(page)
    end
  end
end
