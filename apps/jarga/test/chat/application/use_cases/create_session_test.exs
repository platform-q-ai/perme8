defmodule Jarga.Chat.Application.UseCases.CreateSessionTest do
  @moduledoc """
  Tests for CreateSession use case.
  """
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  alias Jarga.Chat.Application.UseCases.CreateSession
  alias Jarga.Chat.Infrastructure.Schemas.SessionSchema
  alias Jarga.Repo

  describe "execute/1" do
    test "creates a session with user_id" do
      user = user_fixture()

      assert {:ok, session} = CreateSession.execute(%{user_id: user.id})
      assert session.user_id == user.id
      assert session.workspace_id == nil
      assert session.project_id == nil
      assert session.title == nil

      # Verify it was persisted
      persisted = Repo.get(SessionSchema, session.id)
      assert persisted.id == session.id
    end

    test "creates a session with workspace_id" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, session} =
               CreateSession.execute(%{
                 user_id: user.id,
                 workspace_id: workspace.id
               })

      assert session.user_id == user.id
      assert session.workspace_id == workspace.id
      assert session.project_id == nil
    end

    test "creates a session with project_id" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      assert {:ok, session} =
               CreateSession.execute(%{
                 user_id: user.id,
                 workspace_id: workspace.id,
                 project_id: project.id
               })

      assert session.user_id == user.id
      assert session.workspace_id == workspace.id
      assert session.project_id == project.id
    end

    test "creates a session with title" do
      user = user_fixture()

      assert {:ok, session} =
               CreateSession.execute(%{
                 user_id: user.id,
                 title: "My Chat Session"
               })

      assert session.title == "My Chat Session"
    end

    test "returns error when user_id is missing" do
      assert {:error, changeset} = CreateSession.execute(%{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "returns error with invalid user_id" do
      fake_id = Ecto.UUID.generate()

      assert {:error, changeset} = CreateSession.execute(%{user_id: fake_id})
      assert %{user_id: ["does not exist"]} = errors_on(changeset)
    end

    test "auto-generates title from first message content if title not provided" do
      user = user_fixture()

      # Create session without title
      {:ok, session} =
        CreateSession.execute(%{
          user_id: user.id,
          first_message: "What is the status of project Alpha?"
        })

      # Title should be generated from first message (truncated to reasonable length)
      expected_title = "What is the status of project Alpha?"
      assert session.title == expected_title
    end

    test "truncates auto-generated title to 50 characters" do
      user = user_fixture()

      long_message =
        "This is a very long message that exceeds fifty characters and should be truncated"

      {:ok, session} =
        CreateSession.execute(%{
          user_id: user.id,
          first_message: long_message
        })

      assert String.length(session.title) <= 50
      assert String.ends_with?(session.title, "...")
    end

    test "uses provided title even when first_message is present" do
      user = user_fixture()

      {:ok, session} =
        CreateSession.execute(%{
          user_id: user.id,
          title: "Custom Title",
          first_message: "Some message content"
        })

      assert session.title == "Custom Title"
    end
  end
end
