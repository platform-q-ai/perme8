defmodule Agents.Sessions.Infrastructure.QueueOrchestratorSupervisor do
  @moduledoc """
  DynamicSupervisor for per-user QueueOrchestrator GenServer processes.
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def ensure_started(user_id, opts \\ []) do
    case Registry.lookup(Agents.Sessions.QueueRegistry, user_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> start_orchestrator(user_id, opts)
    end
  end

  defp start_orchestrator(user_id, opts) do
    opts = Keyword.put(opts, :user_id, user_id)
    spec = {Agents.Sessions.Infrastructure.QueueOrchestrator, opts}

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end
end
