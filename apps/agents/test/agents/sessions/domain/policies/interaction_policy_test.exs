defmodule Agents.Sessions.Domain.Policies.InteractionPolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.Interaction
  alias Agents.Sessions.Domain.Policies.InteractionPolicy

  describe "valid_type?/1" do
    test "accepts all valid types" do
      for type <- [:question, :answer, :instruction, :queued_response] do
        assert InteractionPolicy.valid_type?(type)
      end
    end

    test "rejects invalid types" do
      refute InteractionPolicy.valid_type?(:invalid)
    end
  end

  describe "valid_direction?/1" do
    test "accepts inbound and outbound" do
      assert InteractionPolicy.valid_direction?(:inbound)
      assert InteractionPolicy.valid_direction?(:outbound)
    end

    test "rejects invalid directions" do
      refute InteractionPolicy.valid_direction?(:invalid)
    end
  end

  describe "can_modify?/1" do
    test "returns true for pending interactions" do
      interaction = Interaction.new(%{status: :pending})
      assert InteractionPolicy.can_modify?(interaction)
    end

    test "returns false for delivered interactions" do
      interaction = Interaction.new(%{status: :delivered})
      refute InteractionPolicy.can_modify?(interaction)
    end

    test "returns false for expired interactions" do
      interaction = Interaction.new(%{status: :expired})
      refute InteractionPolicy.can_modify?(interaction)
    end

    test "returns false for timed_out interactions" do
      interaction = Interaction.new(%{status: :timed_out})
      refute InteractionPolicy.can_modify?(interaction)
    end
  end

  describe "can_answer?/1" do
    test "returns true for pending questions" do
      interaction = Interaction.new(%{type: :question, status: :pending})
      assert InteractionPolicy.can_answer?(interaction)
    end

    test "returns false for delivered questions" do
      interaction = Interaction.new(%{type: :question, status: :delivered})
      refute InteractionPolicy.can_answer?(interaction)
    end

    test "returns false for non-question types" do
      interaction = Interaction.new(%{type: :answer, status: :pending})
      refute InteractionPolicy.can_answer?(interaction)
    end
  end
end
