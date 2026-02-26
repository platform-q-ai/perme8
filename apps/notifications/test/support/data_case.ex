defmodule Notifications.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Notifications.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias Notifications.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Notifications.DataCase
    end
  end

  setup tags do
    Notifications.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.

  Checks out both Notifications.Repo and Identity.Repo since both share
  the same database and notification tests may exercise code that uses
  either repo (e.g., user fixtures via Identity.Repo).
  """
  def setup_sandbox(tags) do
    :ok = Sandbox.checkout(Notifications.Repo)
    :ok = Sandbox.checkout(Identity.Repo)

    Sandbox.allow(Notifications.Repo, self(), self())
    Sandbox.allow(Identity.Repo, self(), self())

    unless tags[:async] do
      Sandbox.mode(Notifications.Repo, {:shared, self()})
      Sandbox.mode(Identity.Repo, {:shared, self()})
    end
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Notifications.create_notification(%{})
      assert "can't be blank" in errors_on(changeset).user_id
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
