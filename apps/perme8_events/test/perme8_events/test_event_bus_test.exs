defmodule Perme8.Events.TestEventBusTest do
  use ExUnit.Case, async: true

  alias Perme8.Events.TestEventBus

  defmodule FakeEvent do
    defstruct [:id, :type]
  end

  describe "named instances (flat list, backward compatible)" do
    setup do
      name = :"test_event_bus_#{System.unique_integer([:positive])}"
      {:ok, pid} = TestEventBus.start_link(name: name)
      %{name: name, pid: pid}
    end

    test "start_link/1 starts an Agent", %{pid: pid} do
      assert Process.alive?(pid)
    end

    test "emit/2 stores event", %{name: name} do
      event = %FakeEvent{id: "1", type: "test"}
      TestEventBus.emit(event, name: name)

      assert [%FakeEvent{id: "1", type: "test"}] = TestEventBus.get_events(name: name)
    end

    test "emit_all/2 stores multiple events", %{name: name} do
      event1 = %FakeEvent{id: "1", type: "first"}
      event2 = %FakeEvent{id: "2", type: "second"}

      TestEventBus.emit_all([event1, event2], name: name)

      assert [%FakeEvent{id: "1"}, %FakeEvent{id: "2"}] = TestEventBus.get_events(name: name)
    end

    test "get_events/1 returns events in emission order", %{name: name} do
      TestEventBus.emit(%FakeEvent{id: "1", type: "first"}, name: name)
      TestEventBus.emit(%FakeEvent{id: "2", type: "second"}, name: name)
      TestEventBus.emit(%FakeEvent{id: "3", type: "third"}, name: name)

      events = TestEventBus.get_events(name: name)
      assert [%FakeEvent{id: "1"}, %FakeEvent{id: "2"}, %FakeEvent{id: "3"}] = events
    end

    test "reset/1 clears all stored events", %{name: name} do
      TestEventBus.emit(%FakeEvent{id: "1", type: "test"}, name: name)
      assert [_] = TestEventBus.get_events(name: name)

      TestEventBus.reset(name: name)
      assert [] = TestEventBus.get_events(name: name)
    end
  end

  describe "global instance (PID-scoped)" do
    setup do
      TestEventBus.start_global()
      :ok
    end

    test "start_global/0 is idempotent" do
      assert {:ok, pid1} = TestEventBus.start_global()
      assert {:ok, pid2} = TestEventBus.start_global()
      assert pid1 == pid2
    end

    test "emit/1 stores events scoped to calling process" do
      event = %FakeEvent{id: "1", type: "test"}
      TestEventBus.emit(event)

      assert [%FakeEvent{id: "1"}] = TestEventBus.get_events()
    end

    test "get_events/0 returns only current process events" do
      TestEventBus.emit(%FakeEvent{id: "1", type: "mine"})

      task =
        Task.async(fn ->
          TestEventBus.emit(%FakeEvent{id: "2", type: "other"})
          TestEventBus.get_events()
        end)

      other_events = Task.await(task)

      assert [%FakeEvent{id: "1", type: "mine"}] = TestEventBus.get_events()
      assert [%FakeEvent{id: "2", type: "other"}] = other_events
    end

    test "reset/0 clears only current process events" do
      TestEventBus.emit(%FakeEvent{id: "1", type: "mine"})

      task =
        Task.async(fn ->
          TestEventBus.emit(%FakeEvent{id: "2", type: "other"})
          TestEventBus.get_events()
        end)

      Task.await(task)
      TestEventBus.reset()

      assert [] = TestEventBus.get_events()
    end

    test "emit_all/1 stores multiple events for calling process" do
      events = [%FakeEvent{id: "1", type: "a"}, %FakeEvent{id: "2", type: "b"}]
      TestEventBus.emit_all(events)

      assert [%FakeEvent{id: "1"}, %FakeEvent{id: "2"}] = TestEventBus.get_events()
    end

    test "allow/3 delegates child process events to owner" do
      parent = self()

      task =
        Task.async(fn ->
          receive do
            :go -> :ok
          end

          TestEventBus.emit(%FakeEvent{id: "child", type: "delegated"})
        end)

      TestEventBus.allow(TestEventBus, parent, task.pid)
      send(task.pid, :go)
      Task.await(task)

      assert [%FakeEvent{id: "child", type: "delegated"}] = TestEventBus.get_events()
    end
  end
end
