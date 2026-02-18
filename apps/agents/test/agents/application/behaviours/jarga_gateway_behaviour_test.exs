defmodule Agents.Application.Behaviours.JargaGatewayBehaviourTest do
  use ExUnit.Case, async: true

  describe "callbacks" do
    @expected_callbacks [
      list_workspaces: 1,
      get_workspace: 2,
      list_projects: 2,
      create_project: 3,
      get_project: 3,
      list_documents: 3,
      create_document: 3,
      get_document: 3
    ]

    test "defines all 8 Jarga gateway callbacks" do
      callbacks =
        Agents.Application.Behaviours.JargaGatewayBehaviour.behaviour_info(:callbacks)

      for {name, arity} <- @expected_callbacks do
        assert {name, arity} in callbacks,
               "Expected callback #{name}/#{arity} to be defined, got: #{inspect(callbacks)}"
      end

      assert length(callbacks) == 8,
             "Expected exactly 8 callbacks, got #{length(callbacks)}: #{inspect(callbacks)}"
    end
  end
end
