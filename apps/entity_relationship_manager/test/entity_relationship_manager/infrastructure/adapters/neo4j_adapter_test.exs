defmodule EntityRelationshipManager.Infrastructure.Adapters.Neo4jAdapterTest do
  use ExUnit.Case, async: true

  @moduletag :neo4j

  alias EntityRelationshipManager.Infrastructure.Adapters.Neo4jAdapter

  describe "execute/3 with default adapter" do
    test "returns {:error, :not_configured} when no adapter is configured" do
      assert {:error, :not_configured} = Neo4jAdapter.execute("RETURN 1", %{})
    end
  end

  describe "execute/3 with injected adapter module" do
    test "delegates to the provided adapter module" do
      defmodule SuccessAdapter do
        def execute(_cypher, _params) do
          {:ok, %{records: [%{"n" => 1}], summary: %{}}}
        end
      end

      assert {:ok, %{records: [%{"n" => 1}]}} =
               Neo4jAdapter.execute("MATCH (n) RETURN n", %{id: "123"}, adapter: SuccessAdapter)
    end
  end

  describe "health_check/1" do
    test "returns :ok when execute succeeds" do
      defmodule HealthyAdapter do
        def execute(_cypher, _params) do
          {:ok, %{records: [%{"health" => 1}], summary: %{}}}
        end
      end

      assert :ok = Neo4jAdapter.health_check(adapter: HealthyAdapter)
    end

    test "returns error when execute fails" do
      defmodule UnhealthyAdapter do
        def execute(_cypher, _params) do
          {:error, :connection_refused}
        end
      end

      assert {:error, :connection_refused} = Neo4jAdapter.health_check(adapter: UnhealthyAdapter)
    end

    test "returns {:error, :not_configured} when no adapter configured" do
      assert {:error, :not_configured} = Neo4jAdapter.health_check()
    end
  end
end
