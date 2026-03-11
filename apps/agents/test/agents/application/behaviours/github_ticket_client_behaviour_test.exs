defmodule Agents.Application.Behaviours.GithubTicketClientBehaviourTest do
  use ExUnit.Case, async: true

  alias Agents.Application.Behaviours.GithubTicketClientBehaviour

  describe "callbacks" do
    @expected_callbacks [
      get_issue: 2,
      list_issues: 1,
      create_issue: 2,
      update_issue: 3,
      close_issue_with_comment: 2,
      add_comment: 3,
      add_sub_issue: 3,
      remove_sub_issue: 3
    ]

    test "defines all ticket client callbacks" do
      callbacks = GithubTicketClientBehaviour.behaviour_info(:callbacks)

      for {name, arity} <- @expected_callbacks do
        assert {name, arity} in callbacks,
               "Expected callback #{name}/#{arity} to be defined, got: #{inspect(callbacks)}"
      end

      assert length(callbacks) == 8,
             "Expected exactly 8 callbacks, got #{length(callbacks)}: #{inspect(callbacks)}"
    end
  end
end
