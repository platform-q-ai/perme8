defmodule Jarga.ChatFixtures do
  @moduledoc """
  This module defines test helpers for creating
  chat-related entities via the public Chat API.

  These fixtures are used in tests that require database access.
  """

  use Boundary,
    top_level?: true,
    deps: [Jarga.Chat, Jarga.Accounts, Jarga.AccountsFixtures, Jarga.WorkspacesFixtures],
    exports: []

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  @doc """
  Generate a chat session using the public API.

  Accepts:
  - :user or :user_id for the user
  - :workspace or :workspace_id for the workspace (optional, will create if not provided)
  - :project_id for the project (optional)
  - :title for the session title (optional)
  """
  def chat_session_fixture(attrs \\ %{}) do
    # Determine user - priority: attrs[:user], then lookup by user_id, then create new
    user =
      cond do
        attrs[:user] ->
          attrs[:user]

        attrs[:user_id] ->
          # Look up existing user by ID using public Accounts API
          Jarga.Accounts.get_user!(attrs[:user_id])

        true ->
          user_fixture()
      end

    # Determine workspace - priority: attrs[:workspace], then use workspace_id if provided, else create
    workspace_id =
      cond do
        attrs[:workspace] -> attrs[:workspace].id
        attrs[:workspace_id] -> attrs[:workspace_id]
        true -> workspace_fixture(user).id
      end

    {:ok, session} =
      Jarga.Chat.create_session(%{
        user_id: user.id,
        workspace_id: workspace_id,
        title: attrs[:title],
        project_id: attrs[:project_id]
      })

    session
  end

  @doc """
  Generate a chat message using the public API.

  Accepts:
  - :chat_session for the session struct
  - :chat_session_id for the session ID (will be used directly)
  - :role for the message role (default: "user")
  - :content for the message content (default: "Test message content")
  - :context_chunks for context chunks (default: [])
  """
  def chat_message_fixture(attrs \\ %{}) do
    # If chat_session_id is provided directly, use it
    # Otherwise, get session from :chat_session or create new one
    chat_session_id =
      cond do
        attrs[:chat_session_id] -> attrs[:chat_session_id]
        attrs[:chat_session] -> attrs[:chat_session].id
        true -> chat_session_fixture().id
      end

    {:ok, message} =
      Jarga.Chat.save_message(%{
        chat_session_id: chat_session_id,
        role: attrs[:role] || "user",
        content: attrs[:content] || "Test message content",
        context_chunks: attrs[:context_chunks] || []
      })

    message
  end
end
