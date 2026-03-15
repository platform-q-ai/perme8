defmodule ChatTest do
  use Chat.DataCase, async: true

  import Chat.ChatFixtures

  describe "session and message facade functions" do
    test "create_session, list_sessions, load_session, and delete_session" do
      user = chat_user_fixture()

      assert {:ok, session} = Chat.create_session(%{user_id: user.id, title: "Facade session"})

      assert {:ok, sessions} = Chat.list_sessions(user.id)
      assert Enum.any?(sessions, &(&1.id == session.id))

      assert {:ok, loaded} = Chat.load_session(session.id)
      assert loaded.id == session.id

      assert {:ok, _deleted} = Chat.delete_session(session.id, user.id)
      assert {:error, :not_found} = Chat.load_session(session.id)
    end

    test "load_session with custom message_limit" do
      session = chat_session_fixture(%{title: "Paginated"})

      for i <- 1..5 do
        Chat.save_message(%{
          chat_session_id: session.id,
          role: "user",
          content: "msg #{i}"
        })
      end

      assert {:ok, loaded} = Chat.load_session(session.id, message_limit: 3)
      assert loaded.id == session.id
      assert length(loaded.messages) == 3
    end

    test "load_older_messages returns paginated messages" do
      session = chat_session_fixture(%{title: "Scroll"})

      messages =
        for i <- 1..5 do
          {:ok, msg} =
            Chat.save_message(%{
              chat_session_id: session.id,
              role: "user",
              content: "msg #{i}"
            })

          msg
        end

      # Use the last message as cursor to load older ones
      cursor = List.last(messages)

      assert {:ok, older, _has_more?} = Chat.load_older_messages(session.id, cursor.id)
      assert length(older) == 4
      # All returned messages should be at or before the cursor timestamp
      # (same-second collisions are expected with :utc_datetime precision)
      assert Enum.all?(older, fn m -> m.inserted_at <= cursor.inserted_at end)
      # None of the returned messages should be the cursor itself
      refute Enum.any?(older, fn m -> m.id == cursor.id end)
    end

    test "save_message and delete_message" do
      session = chat_session_fixture(%{title: "With message"})

      assert {:ok, message} =
               Chat.save_message(%{
                 chat_session_id: session.id,
                 role: "user",
                 content: "hello"
               })

      assert {:ok, _deleted} = Chat.delete_message(message.id, session.user_id)
    end
  end

  describe "referential integrity" do
    test "create_session succeeds with a real existing user" do
      user = chat_user_fixture()

      assert {:ok, session} = Chat.create_session(%{user_id: user.id, title: "Valid session"})
      assert session.user_id == user.id
    end

    test "create_session fails with {:error, :user_not_found} for a non-existent user_id" do
      assert {:error, :user_not_found} =
               Chat.create_session(%{user_id: Ecto.UUID.generate(), title: "Orphan"})
    end

    test "create_session fails when workspace_id is provided but user is not a member" do
      user = chat_user_fixture()
      other_user = chat_user_fixture()
      workspace = Identity.WorkspacesFixtures.workspace_fixture(other_user)

      assert {:error, :not_a_member} =
               Chat.create_session(%{
                 user_id: user.id,
                 workspace_id: workspace.id,
                 title: "No access"
               })
    end

    test "create_session succeeds when workspace_id is provided and user is a member" do
      user = chat_user_fixture()
      workspace = Identity.WorkspacesFixtures.workspace_fixture(user)

      assert {:ok, session} =
               Chat.create_session(%{
                 user_id: user.id,
                 workspace_id: workspace.id,
                 title: "Has access"
               })

      assert session.workspace_id == workspace.id
    end
  end

  describe "context preparation facade functions" do
    test "prepare_chat_context delegates to use case" do
      context_input = %{
        current_workspace: %{name: "Workspace", slug: "workspace"},
        document: %{slug: "doc"},
        document_title: "Doc",
        note: %{note_content: "Body"}
      }

      assert {:ok, context} = Chat.prepare_chat_context(context_input)
      assert context.current_workspace == "Workspace"
      assert context.document_title == "Doc"
    end

    test "build_system_message and build_system_message_with_agent" do
      context = %{current_workspace: "Workspace", document_title: "Doc", document_content: "Body"}

      assert {:ok, message} = Chat.build_system_message(context)
      assert message.role == "system"

      agent = %{system_prompt: "You are specialized."}
      assert {:ok, combined} = Chat.build_system_message_with_agent(agent, context)
      assert combined.content =~ "You are specialized"
    end
  end
end
