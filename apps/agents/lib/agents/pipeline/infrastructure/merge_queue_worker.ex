defmodule Agents.Pipeline.Infrastructure.MergeQueueWorker do
  @moduledoc "In-memory GenServer that tracks merge queue order and active validation work."

  use GenServer

  @type state :: %{
          queue: [integer()],
          active: integer() | nil,
          failed: %{optional(integer()) => term()}
        }

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: Keyword.get(opts, :name, __MODULE__))
  end

  @spec enqueue(integer(), keyword()) :: {:ok, map()}
  def enqueue(number, opts \\ []) when is_integer(number) do
    GenServer.call(worker_name(opts), {:enqueue, number})
  end

  @spec claim_next(integer(), keyword()) :: {:ok, :claimed | :queued} | {:error, :not_enqueued}
  def claim_next(number, opts \\ []) when is_integer(number) do
    GenServer.call(worker_name(opts), {:claim_next, number})
  end

  @spec complete(integer(), keyword()) :: :ok
  def complete(number, opts \\ []) when is_integer(number) do
    GenServer.call(worker_name(opts), {:complete, number})
  end

  @spec fail(integer(), term(), keyword()) :: :ok
  def fail(number, reason, opts \\ []) when is_integer(number) do
    GenServer.call(worker_name(opts), {:fail, number, reason})
  end

  @spec snapshot(keyword()) :: state()
  def snapshot(opts \\ []) do
    GenServer.call(worker_name(opts), :snapshot)
  end

  @impl true
  def init(_args) do
    {:ok, %{queue: [], active: nil, failed: %{}}}
  end

  @impl true
  def handle_call({:enqueue, number}, _from, state) do
    state =
      cond do
        state.active == number ->
          state

        number in state.queue ->
          state

        true ->
          %{state | queue: state.queue ++ [number], failed: Map.delete(state.failed, number)}
      end

    {:reply, {:ok, entry_for(state, number)}, state}
  end

  def handle_call({:claim_next, number}, _from, %{active: number} = state) do
    {:reply, {:ok, :claimed}, state}
  end

  def handle_call({:claim_next, number}, _from, %{active: nil, queue: [number | rest]} = state) do
    {:reply, {:ok, :claimed}, %{state | active: number, queue: rest}}
  end

  def handle_call({:claim_next, number}, _from, state) do
    reply = if number in state.queue, do: {:ok, :queued}, else: {:error, :not_enqueued}
    {:reply, reply, state}
  end

  def handle_call({:complete, number}, _from, state) do
    state = if state.active == number, do: %{state | active: nil}, else: state
    {:reply, :ok, state}
  end

  def handle_call({:fail, number, reason}, _from, state) do
    state = %{
      state
      | active: if(state.active == number, do: nil, else: state.active),
        failed: Map.put(state.failed, number, reason),
        queue: Enum.reject(state.queue, &(&1 == number))
    }

    {:reply, :ok, state}
  end

  def handle_call(:snapshot, _from, state) do
    {:reply, state, state}
  end

  defp worker_name(opts), do: Keyword.get(opts, :name, __MODULE__)

  defp entry_for(%{active: number}, number), do: %{number: number, status: :validating}

  defp entry_for(%{queue: _queue}, number), do: %{number: number, status: :queued}
end
