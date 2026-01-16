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
  # Needs access to Jarga.Notifications for integration test setup
  use Boundary,
    top_level?: true,
    deps: [Jarga.Repo, Jarga.Notifications, Jarga.Test.SandboxHelper],
    exports: []

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Jarga.Test.SandboxHelper

  using do
    quote do
      alias Jarga.Repo

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

  If the test is tagged with @integration, it will enable PubSub subscribers
  and start the WorkspaceInvitationSubscriber for real-time notifications.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Jarga.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    # Enable PubSub subscribers for integration tests
    if tags[:integration] do
      enable_pubsub_subscribers()
    end
  end

  alias Jarga.Notifications.Infrastructure.Subscribers.WorkspaceInvitationSubscriber

  defp enable_pubsub_subscribers do
    # Enable PubSub in test environment
    original_value = Application.get_env(:jarga, :enable_pubsub_in_test, false)
    Application.put_env(:jarga, :enable_pubsub_in_test, true)

    # Start the subscriber if it's not already running
    subscriber_pid =
      case Process.whereis(WorkspaceInvitationSubscriber) do
        nil ->
          {:ok, pid} = WorkspaceInvitationSubscriber.start_link([])
          pid

        pid ->
          pid
      end

    # Allow the subscriber to access the database
    SandboxHelper.allow_process(subscriber_pid)

    # Restore original config on test exit
    on_exit(fn ->
      Application.put_env(:jarga, :enable_pubsub_in_test, original_value)
    end)
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
