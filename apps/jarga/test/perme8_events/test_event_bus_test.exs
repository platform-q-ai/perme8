defmodule Perme8.Events.TestEventBusTest do
  use ExUnit.Case, async: true

  alias Perme8.Events.TestEventBus

  # Simple test struct to simulate events
  defmodule FakeEvent do
    defstruct [:id, :type]
  end

  setup do
    # Start the TestEventBus with a unique name per test to allow async: true
    name = :"test_event_bus_#{System.unique_integer([:positive])}"
    {:ok, pid} = TestEventBus.start_link(name: name)

    %{name: name, pid: pid}
  end

  describe "start_link/1" do
    test "starts an Agent", %{pid: pid} do
      assert Process.alive?(pid)
    end
  end

  describe "emit/2" do
    test "stores event in Agent state", %{name: name} do
      event = %FakeEvent{id: "1", type: "test"}
      TestEventBus.emit(event, name: name)

      events = TestEventBus.get_events(name: name)
      assert [%FakeEvent{id: "1", type: "test"}] = events
    end
  end

  describe "emit_all/2" do
    test "stores multiple events", %{name: name} do
      event1 = %FakeEvent{id: "1", type: "first"}
      event2 = %FakeEvent{id: "2", type: "second"}

      TestEventBus.emit_all([event1, event2], name: name)

      events = TestEventBus.get_events(name: name)
      assert [%FakeEvent{id: "1"}, %FakeEvent{id: "2"}] = events
    end
  end

  describe "get_events/1" do
    test "returns events in emission order", %{name: name} do
      event1 = %FakeEvent{id: "1", type: "first"}
      event2 = %FakeEvent{id: "2", type: "second"}
      event3 = %FakeEvent{id: "3", type: "third"}

      TestEventBus.emit(event1, name: name)
      TestEventBus.emit(event2, name: name)
      TestEventBus.emit(event3, name: name)

      events = TestEventBus.get_events(name: name)
      assert [%FakeEvent{id: "1"}, %FakeEvent{id: "2"}, %FakeEvent{id: "3"}] = events
    end
  end

  describe "reset/1" do
    test "clears all stored events", %{name: name} do
      event = %FakeEvent{id: "1", type: "test"}
      TestEventBus.emit(event, name: name)

      assert [_] = TestEventBus.get_events(name: name)

      TestEventBus.reset(name: name)

      assert [] = TestEventBus.get_events(name: name)
    end
  end
end
