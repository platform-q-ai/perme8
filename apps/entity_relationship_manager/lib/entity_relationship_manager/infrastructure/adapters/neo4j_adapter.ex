defmodule EntityRelationshipManager.Infrastructure.Adapters.Neo4jAdapter do
  @moduledoc """
  Thin wrapper around Neo4j Bolt driver for executing Cypher queries.

  Delegates to a configurable adapter module that implements `execute/2`.
  In production, this would use Boltx or bolt_sips. For development and
  testing, a mock or stub adapter can be injected via opts or application
  config.

  ## Configuration

      config :entity_relationship_manager, :neo4j_adapter, MyApp.Neo4jBoltAdapter

  ## Usage

      Neo4jAdapter.execute("MATCH (n:Person) RETURN n", %{name: "Alice"})
      Neo4jAdapter.health_check()
  """

  @type query_result :: %{records: list(), summary: map()}

  @doc """
  Execute a parameterized Cypher query.

  Delegates to the configured adapter module's `execute/2` function.
  An adapter can be injected via opts for testing.
  """
  @spec execute(String.t(), map(), keyword()) :: {:ok, query_result()} | {:error, term()}
  def execute(cypher, params \\ %{}, opts \\ []) do
    adapter = Keyword.get(opts, :adapter, get_adapter())
    adapter.execute(cypher, params)
  end

  @doc """
  Check Neo4j connectivity by running a trivial query.

  Returns `:ok` if the query succeeds, `{:error, reason}` otherwise.
  """
  @spec health_check(keyword()) :: :ok | {:error, term()}
  def health_check(opts \\ []) do
    case execute("RETURN 1 AS health", %{}, opts) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_adapter do
    Application.get_env(:entity_relationship_manager, :neo4j_adapter, __MODULE__.DefaultAdapter)
  end
end
