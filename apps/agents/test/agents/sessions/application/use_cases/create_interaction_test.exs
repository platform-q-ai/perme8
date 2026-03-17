defmodule Agents.Sessions.Application.UseCases.CreateInteractionTest do
  use Agents.DataCase, async: true

  import Agents.SessionsFixtures

  alias Agents.Repo
  alias Agents.Sessions.Application.UseCases.CreateInteraction
  alias Agents.Sessions.Domain.Entities.Interaction
  alias Agents.Sessions.Infrastructure.Schemas.InteractionSchema

  @user_id Ecto.UUID.generate()

  describe "execute/2 question/answer pairing" do
    test "creates a question interaction" do
      session = session_fixture(%{user_id: @user_id})

      attrs = %{
        session_id: session.id,
        type: :question,
        direction: :outbound,
        payload: %{text: "What should I do next?"},
        correlation_id: "corr-123"
      }

      assert {:ok, %Interaction{} = interaction} = CreateInteraction.execute(attrs)

      assert interaction.session_id == session.id
      assert interaction.type == :question
      assert interaction.direction == :outbound
      assert interaction.payload == %{text: "What should I do next?"}
      assert interaction.correlation_id == "corr-123"
      assert interaction.status == :pending
    end

    test "creates an answer and marks the corresponding question as delivered" do
      session = session_fixture(%{user_id: @user_id})
      correlation_id = "corr-#{System.unique_integer([:positive])}"

      # First create a pending question via fixture
      question =
        interaction_fixture(%{
          session_id: session.id,
          type: "question",
          direction: "outbound",
          payload: %{text: "What file?"},
          correlation_id: correlation_id,
          status: "pending"
        })

      # Now create an answer with the same correlation_id
      answer_attrs = %{
        session_id: session.id,
        type: :answer,
        direction: :inbound,
        payload: %{text: "Use main.ex"},
        correlation_id: correlation_id
      }

      assert {:ok, %Interaction{} = answer} = CreateInteraction.execute(answer_attrs)

      assert answer.type == :answer
      assert answer.direction == :inbound

      # Verify the original question was marked as delivered
      reloaded = Repo.get!(InteractionSchema, question.id)
      assert reloaded.status == "delivered"
    end

    test "persists the interaction to the database" do
      session = session_fixture(%{user_id: @user_id})

      attrs = %{
        session_id: session.id,
        type: :instruction,
        direction: :inbound,
        payload: %{text: "Run the tests"}
      }

      assert {:ok, %Interaction{} = interaction} = CreateInteraction.execute(attrs)

      persisted = Repo.get!(InteractionSchema, interaction.id)
      assert persisted.type == "instruction"
      assert persisted.direction == "inbound"
      assert persisted.session_id == session.id
    end

    test "creates interaction with string type and direction" do
      session = session_fixture(%{user_id: @user_id})

      attrs = %{
        session_id: session.id,
        type: "question",
        direction: "outbound",
        payload: %{text: "String type test"}
      }

      assert {:ok, %Interaction{} = interaction} = CreateInteraction.execute(attrs)

      assert interaction.type == :question
      assert interaction.direction == :outbound
    end
  end

  describe "execute/2 invalid type/direction" do
    test "returns error for an invalid type" do
      session = session_fixture(%{user_id: @user_id})

      attrs = %{
        session_id: session.id,
        type: :invalid_type,
        direction: :inbound
      }

      assert {:error, :invalid_type} = CreateInteraction.execute(attrs)
    end

    test "returns error for an invalid direction" do
      session = session_fixture(%{user_id: @user_id})

      attrs = %{
        session_id: session.id,
        type: :question,
        direction: :invalid_direction
      }

      assert {:error, :invalid_direction} = CreateInteraction.execute(attrs)
    end

    test "returns error for nil type" do
      session = session_fixture(%{user_id: @user_id})

      attrs = %{
        session_id: session.id,
        type: nil,
        direction: :inbound
      }

      assert {:error, :invalid_type} = CreateInteraction.execute(attrs)
    end

    test "returns error for nil direction" do
      session = session_fixture(%{user_id: @user_id})

      attrs = %{
        session_id: session.id,
        type: :question,
        direction: nil
      }

      assert {:error, :invalid_direction} = CreateInteraction.execute(attrs)
    end

    test "returns error when session_id does not exist" do
      attrs = %{
        session_id: Ecto.UUID.generate(),
        type: :question,
        direction: :outbound
      }

      assert {:error, %Ecto.Changeset{}} = CreateInteraction.execute(attrs)
    end
  end

  describe "execute/2 correlation_id matching" do
    test "does not mark question as delivered when correlation_id does not match" do
      session = session_fixture(%{user_id: @user_id})

      question =
        interaction_fixture(%{
          session_id: session.id,
          correlation_id: "question-corr",
          status: "pending"
        })

      # Create an answer with a different correlation_id
      answer_attrs = %{
        session_id: session.id,
        type: :answer,
        direction: :inbound,
        correlation_id: "different-corr"
      }

      assert {:ok, _answer} = CreateInteraction.execute(answer_attrs)

      # Question should still be pending
      reloaded = Repo.get!(InteractionSchema, question.id)
      assert reloaded.status == "pending"
    end

    test "does not mark already-delivered question" do
      session = session_fixture(%{user_id: @user_id})
      correlation_id = "corr-#{System.unique_integer([:positive])}"

      # Query filters by status: "pending", so delivered questions are not found
      question =
        interaction_fixture(%{
          session_id: session.id,
          correlation_id: correlation_id,
          status: "delivered"
        })

      # Create an answer with the same correlation_id
      answer_attrs = %{
        session_id: session.id,
        type: :answer,
        direction: :inbound,
        correlation_id: correlation_id
      }

      assert {:ok, _answer} = CreateInteraction.execute(answer_attrs)

      # Question should still be delivered (not changed)
      reloaded = Repo.get!(InteractionSchema, question.id)
      assert reloaded.status == "delivered"
    end

    test "answer without correlation_id does not affect any questions" do
      session = session_fixture(%{user_id: @user_id})

      question =
        interaction_fixture(%{
          session_id: session.id,
          correlation_id: "some-corr",
          status: "pending"
        })

      # Create an answer without correlation_id
      answer_attrs = %{
        session_id: session.id,
        type: :answer,
        direction: :inbound,
        correlation_id: nil
      }

      assert {:ok, _answer} = CreateInteraction.execute(answer_attrs)

      # Question should still be pending
      reloaded = Repo.get!(InteractionSchema, question.id)
      assert reloaded.status == "pending"
    end
  end
end
