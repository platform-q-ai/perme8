defmodule Jarga.Documents.Application.Services.NotificationServiceTest do
  use ExUnit.Case, async: true

  alias Jarga.Documents.Application.Services.NotificationService

  describe "behavior" do
    test "defines notify_document_visibility_changed/1 callback" do
      callbacks = NotificationService.behaviour_info(:callbacks)
      assert {:notify_document_visibility_changed, 1} in callbacks
    end

    test "defines notify_document_pinned_changed/1 callback" do
      callbacks = NotificationService.behaviour_info(:callbacks)
      assert {:notify_document_pinned_changed, 1} in callbacks
    end

    test "defines notify_document_title_changed/1 callback" do
      callbacks = NotificationService.behaviour_info(:callbacks)
      assert {:notify_document_title_changed, 1} in callbacks
    end
  end
end
