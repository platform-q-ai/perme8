defmodule Agents.Infrastructure.Gateways.JargaGatewayTest do
  @moduledoc """
  Tests for the JargaGateway adapter that delegates to the Identity and Jarga
  context facades in-process.

  Since this is an in-process delegation adapter, we test that the module
  implements the JargaGatewayBehaviour and that the function signatures are correct.

  Note: Uses __info__(:functions) instead of function_exported?/3 to avoid
  BEAM code server race conditions with concurrent async test suites.
  """
  use ExUnit.Case, async: true

  alias Agents.Infrastructure.Gateways.JargaGateway
  alias Agents.Application.Behaviours.JargaGatewayBehaviour

  # Query once at module attribute level — avoids per-test race conditions
  @exported_functions JargaGateway.__info__(:functions)

  describe "module behaviour" do
    test "implements JargaGatewayBehaviour" do
      behaviours =
        JargaGateway.__info__(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert JargaGatewayBehaviour in behaviours
    end

    test "exports list_workspaces/1" do
      assert {:list_workspaces, 1} in @exported_functions
    end

    test "exports get_workspace/2" do
      assert {:get_workspace, 2} in @exported_functions
    end

    test "exports list_projects/2" do
      assert {:list_projects, 2} in @exported_functions
    end

    test "exports create_project/3" do
      assert {:create_project, 3} in @exported_functions
    end

    test "exports get_project/3" do
      assert {:get_project, 3} in @exported_functions
    end

    test "exports list_documents/3" do
      assert {:list_documents, 3} in @exported_functions
    end

    test "exports create_document/3" do
      assert {:create_document, 3} in @exported_functions
    end

    test "exports get_document/3" do
      assert {:get_document, 3} in @exported_functions
    end
  end
end
