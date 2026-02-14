defmodule EntityRelationshipManager.DataCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require database access.
  """

  use Boundary,
    top_level?: true,
    deps: [
      EntityRelationshipManager,
      Jarga.DataCase
    ],
    exports: []

  use ExUnit.CaseTemplate

  using do
    quote do
      import EntityRelationshipManager.DataCase
    end
  end

  setup tags do
    Jarga.DataCase.setup_sandbox(tags)
    :ok
  end
end
