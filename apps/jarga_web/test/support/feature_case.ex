defmodule JargaWeb.FeatureCase do
  @moduledoc """
  Base test case for Wallaby feature tests.

  Provides common setup, helpers, and utilities for E2E browser tests.
  """

  # Test support module - top-level boundary for E2E test infrastructure
  use Boundary,
    top_level?: true,
    deps: [
      Jarga.Repo,
      Jarga.Accounts,
      Jarga.Workspaces,
      Jarga.Projects,
      Jarga.Documents,
      Jarga.TestUsers,
      Jarga.Test.SandboxHelper
    ],
    exports: []

  use ExUnit.CaseTemplate

  alias Jarga.Test.SandboxHelper
  alias Jarga.TestUsers
  alias Phoenix.Ecto.SQL.Sandbox, as: PhoenixSandbox
  alias JargaWeb.DocumentSaveDebouncerSupervisor

  using do
    quote do
      use Wallaby.Feature

      import Wallaby.Query
      import JargaWeb.FeatureCase.Helpers

      alias Jarga.Accounts
      alias Jarga.Workspaces
      alias Jarga.Projects
      alias Jarga.Documents
      alias Agents

      # Import fixtures for test data creation
      import Jarga.AccountsFixtures
      import Jarga.WorkspacesFixtures
      import Jarga.ProjectsFixtures
      import Jarga.DocumentsFixtures
      import Agents.AgentsFixtures
    end
  end

  setup _tags do
    SandboxHelper.setup_test_sandbox()

    # Ensure test users exist (idempotent)
    TestUsers.ensure_test_users_exist()

    # Allow the DocumentSaveDebouncerSupervisor and its children to access the sandbox
    # The supervisor spawns DocumentSaveDebouncer processes dynamically during tests
    allow_debouncer_supervisor()

    metadata = PhoenixSandbox.metadata_for(Jarga.Repo, self())
    {:ok, session} = Wallaby.start_session(metadata: metadata)

    # Periodically allow any new debouncer processes that get spawned
    # This handles the case where DocumentSaveDebouncer processes are created
    # during the test execution (e.g., when editing a document)
    task_pid = spawn_link(fn -> periodically_allow_debouncers() end)

    on_exit(fn ->
      # Clean up the periodic task
      if Process.alive?(task_pid), do: Process.exit(task_pid, :normal)
    end)

    {:ok, session: session}
  end

  defp allow_debouncer_supervisor do
    case Process.whereis(DocumentSaveDebouncerSupervisor) do
      nil -> :ok
      pid -> SandboxHelper.allow_process_with_children(pid)
    end
  end

  defp periodically_allow_debouncers do
    # Allow the supervisor and all its current children
    allow_debouncer_supervisor()

    # Wait a bit and repeat
    Process.sleep(100)
    periodically_allow_debouncers()
  end
end
