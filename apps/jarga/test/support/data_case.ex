defmodule Jarga.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Jarga.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  # Test support module - top-level boundary for test infrastructure
  # Needs access to Notifications and Chat repo boundaries (for sandboxed repo usage)
  use Boundary,
    top_level?: true,
    deps: [Jarga.Repo, Jarga.Test.SandboxHelper, Notifications, Notifications.Repo],
    exports: []

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      # Use Jarga.Repo as the default Repo in tests.
      # In test setup, Jarga.Repo is routed through Identity.Repo's sandbox
      # connection via put_dynamic_repo, so all repos share the same transaction.
      alias Jarga.Repo, as: Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Jarga.DataCase
    end
  end

  setup tags do
    Jarga.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.

  IMPORTANT: Jarga.Repo, Identity.Repo, Agents.Repo, and Notifications.Repo all
  point to the same PostgreSQL database. We checkout all repos and allow them to
  share data so foreign key constraints work across repos.
  """
  def setup_sandbox(tags) do
    # Checkout all repos that share the same database.
    # IMPORTANT: Jarga.Repo and Identity.Repo share the same PostgreSQL database.
    # We checkout both and route Jarga.Repo through Identity.Repo's sandbox
    # connection via put_dynamic_repo so that data inserted via Identity.Repo
    # (users, workspaces) is visible to Jarga.Repo queries within the same
    # test transaction. Without this, FK constraints fail because each repo's
    # sandbox runs in a separate DB transaction with no cross-visibility.
    #
    # For spawned processes (LiveView channels, GenServers), shared mode ensures
    # they can access Jarga.Repo's own pool directly - shared mode makes all
    # processes in the same sandbox share a single connection, so FK constraints
    # are satisfied regardless of which repo is used.
    :ok = Sandbox.checkout(Identity.Repo)
    :ok = Sandbox.checkout(Jarga.Repo)
    :ok = Sandbox.checkout(Agents.Repo)
    :ok = Sandbox.checkout(Chat.Repo)
    :ok = Sandbox.checkout(Notifications.Repo)

    # Route Jarga.Repo through Identity.Repo for the test process.
    # This ensures the test process sees consistent data across repos.
    Jarga.Repo.put_dynamic_repo(Identity.Repo)

    Sandbox.allow(Identity.Repo, self(), self())
    Sandbox.allow(Jarga.Repo, self(), self())
    Sandbox.allow(Agents.Repo, self(), self())
    Sandbox.allow(Chat.Repo, self(), self())
    Sandbox.allow(Notifications.Repo, self(), self())

    unless tags[:async] do
      # In non-async mode, share the connection with any spawned processes.
      # Shared mode is critical for LiveView tests where spawned channel
      # processes call Jarga.Repo directly (without the dynamic repo override).
      Sandbox.mode(Identity.Repo, {:shared, self()})
      Sandbox.mode(Jarga.Repo, {:shared, self()})
      Sandbox.mode(Agents.Repo, {:shared, self()})
      Sandbox.mode(Chat.Repo, {:shared, self()})
      Sandbox.mode(Notifications.Repo, {:shared, self()})
    end

    on_exit(fn ->
      Sandbox.checkin(Identity.Repo)
      Sandbox.checkin(Jarga.Repo)
      Sandbox.checkin(Agents.Repo)
      Sandbox.checkin(Chat.Repo)
      Sandbox.checkin(Notifications.Repo)
    end)

    # Enable PubSub subscribers for integration tests
    if tags[:integration] do
      enable_pubsub_subscribers()
    end
  end

  alias Jarga.Test.SandboxHelper

  defp enable_pubsub_subscribers do
    # Use the Notifications public facade to start subscribers.
    # This avoids reaching into Notifications internals from Jarga.
    subscriber_pids = Notifications.ensure_subscribers_started()

    # Allow subscribers to access the database
    Enum.each(subscriber_pids, &SandboxHelper.allow_process/1)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
