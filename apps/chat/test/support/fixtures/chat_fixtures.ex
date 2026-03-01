defmodule Chat.ChatFixtures do
  @moduledoc """
  Test fixtures for chat-related entities via the Chat public API.
  """

  use Boundary,
    top_level?: true,
    deps: [Chat, Identity, Identity.AccountsFixtures, Identity.WorkspacesFixtures],
    exports: []

  import Identity.AccountsFixtures
  import Identity.WorkspacesFixtures

  def chat_user_fixture(attrs \\ %{}) do
    user_fixture(attrs)
  end

  def chat_session_fixture(attrs \\ %{}) do
    user =
      cond do
        attrs[:user] ->
          attrs[:user]

        attrs[:user_id] ->
          Identity.get_user!(attrs[:user_id])

        true ->
          user_fixture()
      end

    workspace_id =
      cond do
        attrs[:workspace] -> attrs[:workspace].id
        attrs[:workspace_id] -> attrs[:workspace_id]
        true -> workspace_fixture(user).id
      end

    {:ok, session} =
      Chat.create_session(%{
        user_id: user.id,
        workspace_id: workspace_id,
        title: attrs[:title],
        project_id: attrs[:project_id]
      })

    session
  end

  def chat_message_fixture(attrs \\ %{}) do
    chat_session_id =
      cond do
        attrs[:chat_session_id] -> attrs[:chat_session_id]
        attrs[:chat_session] -> attrs[:chat_session].id
        true -> chat_session_fixture().id
      end

    {:ok, message} =
      Chat.save_message(%{
        chat_session_id: chat_session_id,
        role: attrs[:role] || "user",
        content: attrs[:content] || "Test message content",
        context_chunks: attrs[:context_chunks] || []
      })

    message
  end
end
