defmodule Perme8.Events.TestEventBus do
  @moduledoc """
  In-memory event bus for testing.

  Stores emitted events in an Agent, allowing tests to assert
  which events were emitted and in what order.

  ## Usage

      setup do
        {:ok, _pid} = Perme8.Events.TestEventBus.start_link([])
        :ok
      end

      test "emits an event" do
        MyUseCase.execute(params, event_bus: Perme8.Events.TestEventBus)

        assert [%MyEvent{}] = Perme8.Events.TestEventBus.get_events()
      end

  ## Named Instances

  For async tests, pass a unique `:name` option:

      {:ok, _pid} = TestEventBus.start_link(name: :my_test_bus)
      TestEventBus.emit(event, name: :my_test_bus)
      TestEventBus.get_events(name: :my_test_bus)
  """

  @default_name __MODULE__

  @doc "Starts the TestEventBus Agent."
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)
    Agent.start_link(fn -> [] end, name: name)
  end

  @doc "Stores an event. Mimics EventBus.emit/2 API."
  def emit(event, opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)
    Agent.update(name, &[event | &1])
    :ok
  end

  @doc "Stores multiple events. Mimics EventBus.emit_all/2 API."
  def emit_all(events, opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)
    Agent.update(name, &(Enum.reverse(events) ++ &1))
    :ok
  end

  @doc "Returns all stored events in emission order."
  def get_events(opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)
    Agent.get(name, &Enum.reverse/1)
  end

  @doc "Clears all stored events."
  def reset(opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)
    Agent.update(name, fn _ -> [] end)
    :ok
  end
end
