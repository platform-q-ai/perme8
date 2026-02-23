defmodule Webhooks.Infrastructure.Subscribers.OutboundWebhookHandlerTest do
  use ExUnit.Case, async: false

  alias Webhooks.Infrastructure.Subscribers.OutboundWebhookHandler

  describe "subscriptions/0" do
    test "returns the correct event topics" do
      assert OutboundWebhookHandler.subscriptions() == [
               "events:projects",
               "events:documents"
             ]
    end
  end

  describe "handle_event/1" do
    test "dispatches webhook for ProjectCreated event" do
      test_pid = self()

      # Create a mock dispatch use case
      dispatch_fn = fn params, _opts ->
        send(test_pid, {:dispatched, params})
        {:ok, []}
      end

      event = %Jarga.Projects.Domain.Events.ProjectCreated{
        aggregate_id: "project-123",
        actor_id: "user-456",
        workspace_id: "workspace-789",
        project_id: "project-123",
        user_id: "user-456",
        name: "My Project",
        slug: "my-project"
      }

      result = OutboundWebhookHandler.handle_event(event, dispatch_fn: dispatch_fn)

      assert result == :ok
      assert_receive {:dispatched, params}
      assert params.workspace_id == "workspace-789"
      assert params.event_type == "project.created"
      assert is_map(params.payload)
    end

    test "dispatches webhook for DocumentCreated event" do
      test_pid = self()

      dispatch_fn = fn params, _opts ->
        send(test_pid, {:dispatched, params})
        {:ok, []}
      end

      event = %Jarga.Documents.Domain.Events.DocumentCreated{
        aggregate_id: "doc-123",
        actor_id: "user-456",
        workspace_id: "workspace-789",
        document_id: "doc-123",
        project_id: "project-123",
        user_id: "user-456",
        title: "My Document"
      }

      result = OutboundWebhookHandler.handle_event(event, dispatch_fn: dispatch_fn)

      assert result == :ok
      assert_receive {:dispatched, params}
      assert params.workspace_id == "workspace-789"
      assert params.event_type == "document.created"
    end

    test "returns :ok for unmatched event type" do
      # An unknown event struct
      event = %{__struct__: SomeUnknownEvent, workspace_id: "test"}

      assert :ok = OutboundWebhookHandler.handle_event(event)
    end
  end
end
