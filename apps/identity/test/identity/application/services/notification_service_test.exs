defmodule Identity.Application.Services.NotificationServiceTest do
  use ExUnit.Case, async: true

  alias Identity.Application.Services.NotificationService

  describe "behavior" do
    test "defines notify_existing_user/3 callback" do
      callbacks = NotificationService.behaviour_info(:callbacks)
      assert {:notify_existing_user, 3} in callbacks
    end

    test "defines notify_new_user/3 callback" do
      callbacks = NotificationService.behaviour_info(:callbacks)
      assert {:notify_new_user, 3} in callbacks
    end

    test "defines notify_user_removed/2 callback" do
      callbacks = NotificationService.behaviour_info(:callbacks)
      assert {:notify_user_removed, 2} in callbacks
    end

    test "defines notify_workspace_updated/1 callback" do
      callbacks = NotificationService.behaviour_info(:callbacks)
      assert {:notify_workspace_updated, 1} in callbacks
    end
  end
end
