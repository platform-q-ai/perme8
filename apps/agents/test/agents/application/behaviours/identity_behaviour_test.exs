defmodule Agents.Application.Behaviours.IdentityBehaviourTest do
  use ExUnit.Case, async: true

  import Mox

  alias Agents.Application.Behaviours.IdentityBehaviour
  alias Agents.Mocks.IdentityMock

  setup :verify_on_exit!

  describe "callbacks" do
    test "defines get_user/1 callback" do
      callbacks = IdentityBehaviour.behaviour_info(:callbacks)

      assert {:get_user, 1} in callbacks
    end

    test "defines verify_api_key/1 callback" do
      callbacks = IdentityBehaviour.behaviour_info(:callbacks)

      assert {:verify_api_key, 1} in callbacks
    end

    test "defines resolve_workspace_id/1 callback" do
      callbacks = IdentityBehaviour.behaviour_info(:callbacks)

      assert {:resolve_workspace_id, 1} in callbacks
    end

    test "defines api_key_has_permission?/2 callback" do
      callbacks = IdentityBehaviour.behaviour_info(:callbacks)

      assert {:api_key_has_permission?, 2} in callbacks
    end

    test "mox mock implements api_key_has_permission?/2" do
      api_key = %{id: "api-key-id", permissions: ["mcp:knowledge.search"]}

      IdentityMock
      |> expect(:api_key_has_permission?, fn ^api_key, "mcp:knowledge.search" -> true end)

      assert IdentityMock.api_key_has_permission?(api_key, "mcp:knowledge.search")
    end
  end
end
