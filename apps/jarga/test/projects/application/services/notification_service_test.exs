defmodule Jarga.Projects.Application.Services.NotificationServiceTest do
  use ExUnit.Case, async: true

  alias Jarga.Projects.Application.Services.NotificationService

  describe "behavior" do
    test "defines notify_project_created/1 callback" do
      callbacks = NotificationService.behaviour_info(:callbacks)
      assert {:notify_project_created, 1} in callbacks
    end

    test "defines notify_project_deleted/2 callback" do
      callbacks = NotificationService.behaviour_info(:callbacks)
      assert {:notify_project_deleted, 2} in callbacks
    end

    test "defines notify_project_updated/1 callback" do
      callbacks = NotificationService.behaviour_info(:callbacks)
      assert {:notify_project_updated, 1} in callbacks
    end
  end
end
