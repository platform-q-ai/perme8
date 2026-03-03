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
  # Needs access to Notifications and Chat boundaries (for sandboxed repo usage)
  use Boundary,
    top_level?: true,
    deps: [Jarga.Repo, Jarga.Test.SandboxHelper, Chat, Notifications, Notifications.Repo],
    exports: []

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      # Use Identity.Repo as the default Repo in tests
      # This ensures all database operations happen in the same transaction
      alias Identity.Repo, as: Repo

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
    # Checkout all repos that share the same database
    :ok = Sandbox.checkout(Jarga.Repo)
    :ok = Sandbox.checkout(Identity.Repo)
    :ok = Sandbox.checkout(Agents.Repo)
    :ok = Sandbox.checkout(Chat.Repo)
    :ok = Sandbox.checkout(Notifications.Repo)

    # CRITICAL: Allow all repos to share data by allowing cross-process access
    # Since all repos connect to the same database, we need to allow them
    # to see each other's uncommitted data for foreign key constraints to work.
    # The trick is to use the same owner (self()) for all repos.
    Sandbox.allow(Jarga.Repo, self(), self())
    Sandbox.allow(Identity.Repo, self(), self())
    Sandbox.allow(Agents.Repo, self(), self())
    Sandbox.allow(Chat.Repo, self(), self())
    Sandbox.allow(Notifications.Repo, self(), self())

    unless tags[:async] do
      # In non-async mode, share the connection with any spawned processes
      Sandbox.mode(Jarga.Repo, {:shared, self()})
      Sandbox.mode(Identity.Repo, {:shared, self()})
      Sandbox.mode(Agents.Repo, {:shared, self()})
      Sandbox.mode(Chat.Repo, {:shared, self()})
      Sandbox.mode(Notifications.Repo, {:shared, self()})
    end

    on_exit(fn ->
      Sandbox.checkin(Jarga.Repo)
      Sandbox.checkin(Identity.Repo)
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
    subscriber_pid = Notifications.ensure_subscribers_started()

    # Allow the subscriber to access the database
    SandboxHelper.allow_process(subscriber_pid)
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
