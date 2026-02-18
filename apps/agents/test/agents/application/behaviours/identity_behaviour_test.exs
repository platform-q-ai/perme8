defmodule Agents.Application.Behaviours.IdentityBehaviourTest do
  use ExUnit.Case, async: true

  alias Agents.Application.Behaviours.IdentityBehaviour

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
  end
end
