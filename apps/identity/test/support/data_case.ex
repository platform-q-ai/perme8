defmodule Identity.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  If the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test.
  """

  # Test support module - top-level boundary for test infrastructure
  use Boundary,
    top_level?: true,
    deps: [Identity.Repo],
    exports: []

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias Identity.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Identity.DataCase
    end
  end

  setup tags do
    Identity.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    :ok = Sandbox.checkout(Identity.Repo)

    unless tags[:async] do
      Sandbox.mode(Identity.Repo, {:shared, self()})
    end

    on_exit(fn ->
      Sandbox.checkin(Identity.Repo)
    end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Context.create_thing(%{field: "bad"})
      assert "is invalid" in errors_on(changeset).field

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
