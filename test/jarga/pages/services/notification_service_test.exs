defmodule Jarga.Pages.Services.NotificationServiceTest do
  use ExUnit.Case, async: true

  alias Jarga.Pages.Services.NotificationService

  describe "behavior" do
    test "defines notify_page_visibility_changed/1 callback" do
      callbacks = NotificationService.behaviour_info(:callbacks)
      assert {:notify_page_visibility_changed, 1} in callbacks
    end

    test "defines notify_page_pinned_changed/1 callback" do
      callbacks = NotificationService.behaviour_info(:callbacks)
      assert {:notify_page_pinned_changed, 1} in callbacks
    end

    test "defines notify_page_title_changed/1 callback" do
      callbacks = NotificationService.behaviour_info(:callbacks)
      assert {:notify_page_title_changed, 1} in callbacks
    end
  end
end
