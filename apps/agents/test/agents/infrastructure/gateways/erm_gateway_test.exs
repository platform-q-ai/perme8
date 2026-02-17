defmodule Agents.Infrastructure.Gateways.ErmGatewayTest do
  @moduledoc """
  Tests for the ErmGateway adapter that delegates to the EntityRelationshipManager facade.

  Since this is an in-process delegation adapter, we test that the module
  implements the ErmGatewayBehaviour and that the function signatures are correct.

  Note: Uses __info__(:functions) instead of function_exported?/3 to avoid
  BEAM code server race conditions with concurrent async test suites.
  """
  use ExUnit.Case, async: true

  alias Agents.Infrastructure.Gateways.ErmGateway
  alias Agents.Application.Behaviours.ErmGatewayBehaviour

  # Query once at module attribute level — avoids per-test race conditions
  @exported_functions ErmGateway.__info__(:functions)

  describe "module behaviour" do
    test "implements ErmGatewayBehaviour" do
      behaviours =
        ErmGateway.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert ErmGatewayBehaviour in behaviours
    end

    test "exports get_schema/1" do
      assert {:get_schema, 1} in @exported_functions
    end

    test "exports upsert_schema/2" do
      assert {:upsert_schema, 2} in @exported_functions
    end

    test "exports create_entity/2" do
      assert {:create_entity, 2} in @exported_functions
    end

    test "exports get_entity/2" do
      assert {:get_entity, 2} in @exported_functions
    end

    test "exports update_entity/3" do
      assert {:update_entity, 3} in @exported_functions
    end

    test "exports list_entities/2" do
      assert {:list_entities, 2} in @exported_functions
    end

    test "exports create_edge/2" do
      assert {:create_edge, 2} in @exported_functions
    end

    test "exports list_edges/2" do
      assert {:list_edges, 2} in @exported_functions
    end

    test "exports get_neighbors/3" do
      assert {:get_neighbors, 3} in @exported_functions
    end

    test "exports traverse/3" do
      assert {:traverse, 3} in @exported_functions
    end
  end
end
