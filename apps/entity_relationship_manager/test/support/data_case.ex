defmodule EntityRelationshipManager.DataCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require database access.
  """

  use Boundary,
    top_level?: true,
    deps: [
      EntityRelationshipManager,
      EntityRelationshipManager.Repo
    ],
    exports: []

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import EntityRelationshipManager.DataCase
    end
  end

  setup tags do
    :ok = Sandbox.checkout(EntityRelationshipManager.Repo)

    unless tags[:async] do
      Sandbox.mode(EntityRelationshipManager.Repo, {:shared, self()})
    end

    on_exit(fn ->
      Sandbox.checkin(EntityRelationshipManager.Repo)
    end)

    :ok
  end
end
