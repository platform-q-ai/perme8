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
