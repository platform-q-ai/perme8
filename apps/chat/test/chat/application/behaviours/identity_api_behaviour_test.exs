defmodule Chat.Application.Behaviours.IdentityApiBehaviourTest do
  use ExUnit.Case, async: true

  alias Chat.Application.Behaviours.IdentityApiBehaviour

  test "module compiles and defines user_exists?/1 callback" do
    callbacks = IdentityApiBehaviour.behaviour_info(:callbacks)
    assert {:user_exists?, 1} in callbacks
  end

  test "module compiles and defines validate_workspace_access/2 callback" do
    callbacks = IdentityApiBehaviour.behaviour_info(:callbacks)
    assert {:validate_workspace_access, 2} in callbacks
  end
end
