defmodule EntityRelationshipManager.Infrastructure.Adapters.Neo4jAdapter.DefaultAdapter do
  @moduledoc """
  Default Neo4j adapter that returns an error indicating
  no Neo4j driver has been configured.

  Replace this with a real Boltx-based adapter when Neo4j is provisioned.
  """

  @doc """
  Returns `{:error, :not_configured}` for all queries.
  """
  @spec execute(String.t(), map()) :: {:error, :not_configured}
  def execute(_cypher, _params) do
    {:error, :not_configured}
  end
end
