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
      Jarga.TestUsers
    ],
    exports: []

  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.Feature

      import Wallaby.Query
      import JargaWeb.FeatureCase.Helpers

      alias Jarga.Repo
      alias Jarga.Accounts
      alias Jarga.Workspaces
      alias Jarga.Projects
      alias Jarga.Documents
      alias Jarga.Agents

      # Import fixtures for test data creation
      import Jarga.AccountsFixtures
      import Jarga.WorkspacesFixtures
      import Jarga.ProjectsFixtures
      import Jarga.DocumentsFixtures
      import Jarga.AgentsFixtures
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Jarga.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, {:shared, self()})
    end

    # Ensure test users exist (idempotent)
    Jarga.TestUsers.ensure_test_users_exist()

    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Jarga.Repo, self())
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end
end
