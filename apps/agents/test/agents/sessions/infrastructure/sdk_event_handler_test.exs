defmodule Agents.Sessions.Infrastructure.SdkEventHandlerTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.Session
  alias Agents.Sessions.Infrastructure.SdkEventHandler

  defmodule TestEventBus do
    def emit_all(events, _opts \\ []) do
      send(self(), {:events_emitted, events})
      :ok
    end
  end

  defp running_session do
    Session.new(%{task_id: "task-1", user_id: "user-1", lifecycle_state: :running})
  end

  defp sdk_event(type, properties) do
    %{"type" => type, "properties" => properties}
  end

  describe "handle/3" do
    test "processes a handled event and returns updated session" do
      session = running_session()

      event =
        sdk_event("session.status", %{
          "status" => "retry",
          "attempt" => 2,
          "message" => "Rate limited"
        })

      assert {:ok, updated} = SdkEventHandler.handle(session, event, event_bus: TestEventBus)
      assert updated.retry_attempt == 2
      assert_received {:events_emitted, events}
      assert length(events) > 0
    end

    test "emits all domain events via event_bus" do
      session = running_session()
      event = sdk_event("session.error", %{"category" => "auth", "message" => "Bad key"})

      assert {:ok, updated} = SdkEventHandler.handle(session, event, event_bus: TestEventBus)
      assert updated.lifecycle_state == :failed
      assert_received {:events_emitted, events}
      assert length(events) == 2
    end

    test "returns skip for ignored event types" do
      session = running_session()
      event = sdk_event("pty.created", %{})

      assert {:skip, :not_relevant} =
               SdkEventHandler.handle(session, event, event_bus: TestEventBus)

      refute_received {:events_emitted, _}
    end

    test "returns skip when policy skips (e.g., terminal session)" do
      session = Session.new(%{task_id: "t", user_id: "u", lifecycle_state: :failed})
      event = sdk_event("session.status", %{"status" => "busy"})

      assert {:skip, :already_terminal} =
               SdkEventHandler.handle(session, event, event_bus: TestEventBus)

      refute_received {:events_emitted, _}
    end

    test "handles event with no events to emit" do
      session = running_session()
      event = sdk_event("session.status", %{"status" => "busy"})

      assert {:ok, updated} = SdkEventHandler.handle(session, event, event_bus: TestEventBus)
      assert updated.lifecycle_state == :running
      refute_received {:events_emitted, _}
    end

    test "uses default event bus when no option provided" do
      session = running_session()
      event = sdk_event("session.status", %{"status" => "busy"})

      assert {:ok, _updated} = SdkEventHandler.handle(session, event, event_bus: TestEventBus)
    end
  end
end
