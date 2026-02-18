defmodule Perme8.Events.EventHandlerTest do
  use Jarga.DataCase, async: false

  import ExUnit.CaptureLog

  # A test event struct
  defmodule TestEvent do
    use Perme8.Events.DomainEvent,
      aggregate_type: "test",
      fields: [data: nil],
      required: []
  end

  # A test handler that implements the EventHandler behaviour
  defmodule TestHandler do
    use Perme8.Events.EventHandler

    @impl true
    def subscriptions do
      ["events:test_handler"]
    end

    @impl true
    def handle_event(event) do
      # Send the event to the test process for assertion
      send(Process.whereis(:event_handler_test_process), {:handled, event})
      :ok
    end
  end

  # A test handler that returns errors
  defmodule ErrorHandler do
    use Perme8.Events.EventHandler

    @impl true
    def subscriptions do
      ["events:error_handler"]
    end

    @impl true
    def handle_event(_event) do
      {:error, :something_went_wrong}
    end
  end

  setup do
    # Register the test process so handlers can send messages back
    Process.register(self(), :event_handler_test_process)

    on_exit(fn ->
      try do
        Process.unregister(:event_handler_test_process)
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  describe "handler compilation" do
    test "handler using EventHandler compiles successfully" do
      # The TestHandler module is defined above — if it compiles, this passes
      assert Code.ensure_loaded?(TestHandler)
    end
  end

  describe "start and subscription" do
    test "handler starts as GenServer and auto-subscribes to topics" do
      {:ok, pid} = TestHandler.start_link([])
      assert Process.alive?(pid)

      # Broadcast on the subscribed topic and verify the handler receives it
      event = TestEvent.new(%{aggregate_id: "agg-1", actor_id: "act-1", data: "hello"})
      Phoenix.PubSub.broadcast(Jarga.PubSub, "events:test_handler", event)

      assert_receive {:handled, %TestEvent{data: "hello"}}, 1000

      GenServer.stop(pid)
    end
  end

  describe "event routing" do
    test "handler receives events via handle_info and routes to handle_event/1" do
      {:ok, pid} = TestHandler.start_link([])

      event = TestEvent.new(%{aggregate_id: "agg-1", actor_id: "act-1", data: "routed"})
      Phoenix.PubSub.broadcast(Jarga.PubSub, "events:test_handler", event)

      assert_receive {:handled, %TestEvent{data: "routed"}}, 1000

      GenServer.stop(pid)
    end

    test "handler ignores non-event messages" do
      {:ok, pid} = TestHandler.start_link([])

      # Send a non-struct message
      send(pid, :not_an_event)
      send(pid, "string message")
      send(pid, {:tuple, :message})

      # Give it time to process
      Process.sleep(50)

      # The handler should still be alive (didn't crash)
      assert Process.alive?(pid)

      # The test process should NOT have received any :handled messages
      refute_receive {:handled, _}, 100

      GenServer.stop(pid)
    end
  end

  describe "error handling" do
    test "handler logs errors when handle_event/1 returns {:error, reason}" do
      {:ok, pid} = ErrorHandler.start_link([])

      log =
        capture_log(fn ->
          event = TestEvent.new(%{aggregate_id: "agg-1", actor_id: "act-1", data: "fail"})
          Phoenix.PubSub.broadcast(Jarga.PubSub, "events:error_handler", event)
          # Give it time to process
          Process.sleep(100)
        end)

      assert log =~ "something_went_wrong"

      GenServer.stop(pid)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec for supervisors" do
      spec = TestHandler.child_spec([])

      assert spec.id == TestHandler
      assert spec.start == {TestHandler, :start_link, [[]]}
      assert spec.type == :worker
      assert spec.restart == :permanent
    end
  end
end
