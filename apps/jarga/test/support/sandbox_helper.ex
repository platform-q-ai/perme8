defmodule Jarga.Test.SandboxHelper do
  @moduledoc """
  Helper functions for managing Ecto Sandbox access in tests.

  Provides utilities to ensure spawned processes (GenServers, Tasks, etc.)
  have proper database access during JavaScript and integration tests.

  This module lives in test/support and is only compiled during tests.

  Supports both Jarga.Repo and Identity.Repo for the umbrella app setup.
  """

  # Test support module - top-level boundary for sandbox management
  use Boundary, top_level?: true, deps: [Jarga.Repo, Identity.Repo], exports: []

  alias Ecto.Adapters.SQL.Sandbox

  @repos [Jarga.Repo, Identity.Repo]

  @doc """
  Allow a process to access the Ecto Sandbox.

  This should be called after spawning any process that needs database access
  during tests (e.g., DocumentSaveDebouncer, PubSub subscribers).

  ## Examples

      # Allow a GenServer process
      {:ok, pid} = GenServer.start_link(MyServer, args)
      SandboxHelper.allow_process(pid)

      # Allow a DocumentSaveDebouncer
      debouncer_pid = DocumentSaveDebouncer.request_save(doc_id, user, note_id, state, markdown)
      SandboxHelper.allow_process(debouncer_pid)

  """
  def allow_process(pid) when is_pid(pid) do
    Enum.each(@repos, fn repo ->
      Sandbox.allow(repo, self(), pid)
    end)
  end

  @doc """
  Allow multiple processes to access the Ecto Sandbox.

  Useful for allowing multiple background processes at once.

  ## Examples

      pids = [debouncer_pid, subscriber_pid, task_pid]
      SandboxHelper.allow_processes(pids)
  """
  def allow_processes(pids) when is_list(pids) do
    Enum.each(pids, &allow_process/1)
  end

  @doc """
  Allow a process and its children to access the Ecto Sandbox.

  Some processes spawn additional child processes that also need database access.
  This function ensures both parent and children have sandbox access.

  ## Examples

      {:ok, supervisor_pid} = Supervisor.start_link(children, strategy: :one_for_one)
      SandboxHelper.allow_process_with_children(supervisor_pid)
  """
  def allow_process_with_children(supervisor_pid) when is_pid(supervisor_pid) do
    # Allow the supervisor itself on all repos
    allow_process(supervisor_pid)

    # Allow all child processes on all repos
    supervisor_pid
    |> Supervisor.which_children()
    |> Enum.each(&allow_child_process/1)
  end

  defp allow_child_process({_id, child_pid, _type, _modules}) when is_pid(child_pid) do
    allow_process(child_pid)
  end

  defp allow_child_process(_), do: :ok

  @doc """
  Setup sandbox for the current test process in shared mode.

  This allows spawned processes to automatically share the sandbox connection.
  Call this in test setup blocks.
  """
  def setup_test_sandbox do
    Enum.each(@repos, fn repo ->
      :ok = Sandbox.checkout(repo)
      # Use shared mode to allow child processes to access the connection
      # This allows any process spawned by the test process to share the connection
      Sandbox.mode(repo, {:shared, self()})
    end)
  end

  @doc """
  Get the owner PID for the current sandbox connection.

  This is useful for allowing processes in nested contexts.
  """
  def get_owner_pid do
    self()
  end

  @doc """
  Allow any dynamically spawned process to access the sandbox.

  This is useful for processes that are created during the test execution
  (e.g., DocumentSaveDebouncer processes created by LiveView interactions).

  Call this in on_exit to ensure all spawned processes are allowed.
  """
  def allow_all_spawned_processes do
    # Get all processes in the current application
    processes = Process.list()

    Enum.each(processes, fn pid ->
      Enum.each(@repos, fn repo ->
        try do
          # Try to allow each process - will fail silently if already allowed
          Sandbox.allow(repo, self(), pid)
        rescue
          # Ignore errors (process may not exist or may not need sandbox access)
          _ -> :ok
        end
      end)
    end)
  end
end
