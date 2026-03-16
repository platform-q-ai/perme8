defmodule Agents.Sessions.Domain.Entities.InteractionTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.Interaction

  describe "new/1" do
    test "creates interaction with defaults" do
      interaction = Interaction.new(%{})
      assert interaction.payload == %{}
      assert interaction.status == :pending
    end

    test "creates interaction with provided attributes" do
      interaction =
        Interaction.new(%{
          id: "int-1",
          session_id: "sess-1",
          type: :question,
          direction: :outbound,
          payload: %{question: "Which approach?"},
          correlation_id: "q-001",
          status: :pending
        })

      assert interaction.id == "int-1"
      assert interaction.session_id == "sess-1"
      assert interaction.type == :question
      assert interaction.direction == :outbound
      assert interaction.correlation_id == "q-001"
    end
  end

  describe "type predicates" do
    test "question?/1" do
      assert Interaction.question?(Interaction.new(%{type: :question}))
      refute Interaction.question?(Interaction.new(%{type: :answer}))
    end

    test "answer?/1" do
      assert Interaction.answer?(Interaction.new(%{type: :answer}))
      refute Interaction.answer?(Interaction.new(%{type: :question}))
    end

    test "instruction?/1" do
      assert Interaction.instruction?(Interaction.new(%{type: :instruction}))
      refute Interaction.instruction?(Interaction.new(%{type: :question}))
    end

    test "queued_response?/1" do
      assert Interaction.queued_response?(Interaction.new(%{type: :queued_response}))
      refute Interaction.queued_response?(Interaction.new(%{type: :question}))
    end
  end

  describe "status predicates" do
    test "pending?/1" do
      assert Interaction.pending?(Interaction.new(%{status: :pending}))
      refute Interaction.pending?(Interaction.new(%{status: :delivered}))
    end

    test "delivered?/1" do
      assert Interaction.delivered?(Interaction.new(%{status: :delivered}))
      refute Interaction.delivered?(Interaction.new(%{status: :pending}))
    end

    test "expired?/1" do
      assert Interaction.expired?(Interaction.new(%{status: :expired}))
      refute Interaction.expired?(Interaction.new(%{status: :pending}))
    end
  end
end
