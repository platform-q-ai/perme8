defmodule Agents.Pipeline.Domain.Policies.PullRequestPolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Policies.PullRequestPolicy

  describe "valid_transition?/2" do
    test "allows expected state transitions" do
      assert :ok == PullRequestPolicy.valid_transition?("draft", "open")
      assert :ok == PullRequestPolicy.valid_transition?("open", "in_review")
      assert :ok == PullRequestPolicy.valid_transition?("in_review", "approved")
      assert :ok == PullRequestPolicy.valid_transition?("approved", "merged")
      assert :ok == PullRequestPolicy.valid_transition?("open", "closed")
    end

    test "rejects invalid transitions" do
      assert {:error, :invalid_transition} =
               PullRequestPolicy.valid_transition?("draft", "merged")

      assert {:error, :invalid_transition} = PullRequestPolicy.valid_transition?("merged", "open")

      assert {:error, :invalid_transition} =
               PullRequestPolicy.valid_transition?("closed", "approved")
    end
  end
end
