defmodule Agents.Sessions.Infrastructure.TaskRunnerSupervisor do
  @moduledoc """
  DynamicSupervisor for TaskRunner GenServer processes.

  Each coding task gets its own TaskRunner process, managed by this supervisor.
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new TaskRunner child process for the given task.
  """
  def start_child(task_id, opts \\ []) do
    spec = {Agents.Sessions.Infrastructure.TaskRunner, {task_id, opts}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
