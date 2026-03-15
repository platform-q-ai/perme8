defmodule EntityRelationshipManager.Infrastructure.Adapters.Neo4jAdapter.HttpAdapterTest do
  @moduledoc """
  Integration tests for the HttpAdapter (Neo4j HTTP API adapter).

  These tests require a running Neo4j instance and are excluded by default
  (tagged :neo4j). Run with:

      mix test --include neo4j apps/entity_relationship_manager
  """
  use ExUnit.Case, async: false

  @moduletag :neo4j

  alias EntityRelationshipManager.Infrastructure.Adapters.Neo4jAdapter.HttpAdapter

  describe "execute/2" do
    test "runs a trivial Cypher query" do
      assert {:ok, %{records: records}} = HttpAdapter.execute("RETURN 1 AS n", %{})
      assert [%{"n" => 1}] = records
    end

    test "supports parameterized queries" do
      assert {:ok, %{records: records}} =
               HttpAdapter.execute("RETURN $value AS v", %{value: "hello"})

      assert [%{"v" => "hello"}] = records
    end

    test "returns error for invalid Cypher" do
      assert {:error, {:neo4j_error, _message}} =
               HttpAdapter.execute("INVALID CYPHER SYNTAX !!!", %{})
    end
  end
end
