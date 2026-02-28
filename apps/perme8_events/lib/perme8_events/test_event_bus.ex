defmodule Perme8.Events.TestEventBus do
  @moduledoc """
  In-memory event bus for testing with per-process isolation.

  Events are stored in a map keyed by the calling process PID, so each
  async test automatically gets its own isolated event store without
  any cross-test leakage.

  ## Global Instance (recommended for most tests)

  Call `start_global/0` in your setup block. The global singleton is
  started once and reused; each test process sees only its own events:

      setup do
        TestEventBus.start_global()
        :ok
      end

      test "emits an event" do
        MyUseCase.execute(params, event_bus: Perme8.Events.TestEventBus)
        assert [%MyEvent{}] = Perme8.Events.TestEventBus.get_events()
      end

  ## Named Instances

  For advanced use (e.g. notifications), pass a unique `:name` option.
  Named instances use a flat list (no PID scoping):

      {:ok, _pid} = TestEventBus.start_link(name: :my_test_bus)
      TestEventBus.emit(event, name: :my_test_bus)
      TestEventBus.get_events(name: :my_test_bus)

  ## Process Delegation

  If events are emitted from a spawned child process (Task, GenServer),
  call `allow/3` to delegate the child's events to the test process:

      TestEventBus.allow(TestEventBus, self(), child_pid)
  """

  @default_name __MODULE__

  # ---------------------------------------------------------------------------
  # Start / lifecycle
  # ---------------------------------------------------------------------------

  @doc """
  Starts a named TestEventBus Agent.

  With no `:name` option the default name `Perme8.Events.TestEventBus` is used.
  Named instances use a **flat list** (no PID scoping) for backward compatibility.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)

    if name == @default_name do
      Agent.start_link(fn -> %{events: %{}, allowances: %{}} end, name: name)
    else
      Agent.start_link(fn -> [] end, name: name)
    end
  end

  @doc """
  Ensures the global TestEventBus singleton is running. Idempotent.

  Returns `{:ok, pid}` whether it started a new process or found an existing one.
  Automatically registers the calling test process for cleanup via `on_exit`.
  """
  def start_global do
    pid =
      case start_link([]) do
        {:ok, p} ->
          Process.unlink(p)
          p

        {:error, {:already_started, p}} ->
          p
      end

    caller = self()

    ExUnit.Callbacks.on_exit(fn ->
      try do
        Agent.update(@default_name, fn state ->
          events = Map.delete(state.events, caller)

          allowances =
            state.allowances
            |> Enum.reject(fn {_child, owner} -> owner == caller end)
            |> Map.new()

          %{state | events: events, allowances: allowances}
        end)
      catch
        :exit, _ -> :ok
      end
    end)

    {:ok, pid}
  end

  # ---------------------------------------------------------------------------
  # Allow (process delegation)
  # ---------------------------------------------------------------------------

  @doc """
  Delegates events from `child_pid` to `owner_pid`.

  When a child process emits an event, it will be stored under `owner_pid`'s
  event list. Only works with the global (PID-scoped) instance.
  """
  def allow(@default_name, owner_pid, child_pid) do
    Agent.update(@default_name, fn state ->
      %{state | allowances: Map.put(state.allowances, child_pid, owner_pid)}
    end)

    :ok
  end

  def allow(_name, _owner_pid, _child_pid), do: :ok

  # ---------------------------------------------------------------------------
  # Emit
  # ---------------------------------------------------------------------------

  @doc "Stores an event. Mimics EventBus.emit/2 API."
  def emit(event, opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)

    if name == @default_name do
      caller = self()

      Agent.update(name, fn state ->
        owner = Map.get(state.allowances, caller, caller)
        events = Map.update(state.events, owner, [event], &[event | &1])
        %{state | events: events}
      end)
    else
      Agent.update(name, &[event | &1])
    end

    :ok
  end

  @doc "Stores multiple events. Mimics EventBus.emit_all/2 API."
  def emit_all(events, opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)

    if name == @default_name do
      caller = self()

      Agent.update(name, fn state ->
        owner = Map.get(state.allowances, caller, caller)

        updated =
          Map.update(state.events, owner, Enum.reverse(events), &(Enum.reverse(events) ++ &1))

        %{state | events: updated}
      end)
    else
      Agent.update(name, &(Enum.reverse(events) ++ &1))
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Query
  # ---------------------------------------------------------------------------

  @doc "Returns all stored events in emission order for the calling process."
  def get_events(opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)

    if name == @default_name do
      caller = self()

      Agent.get(name, fn state ->
        owner = Map.get(state.allowances, caller, caller)

        state.events
        |> Map.get(owner, [])
        |> Enum.reverse()
      end)
    else
      Agent.get(name, &Enum.reverse/1)
    end
  end

  # ---------------------------------------------------------------------------
  # Reset
  # ---------------------------------------------------------------------------

  @doc "Clears stored events for the calling process (global) or all events (named)."
  def reset(opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)

    if name == @default_name do
      caller = self()

      Agent.update(name, fn state ->
        owner = Map.get(state.allowances, caller, caller)
        %{state | events: Map.delete(state.events, owner)}
      end)
    else
      Agent.update(name, fn _ -> [] end)
    end

    :ok
  end
end
