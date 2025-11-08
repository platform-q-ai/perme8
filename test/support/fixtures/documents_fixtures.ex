defmodule Jarga.DocumentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Jarga.Documents` context.
  """

  use Boundary, top_level?: true, deps: [Jarga.Documents, Jarga.Repo], exports: []

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Jarga.Repo

  @doc """
  Generate a chat session.
  """
  def chat_session_fixture(attrs \\ %{}) do
    user = attrs[:user] || user_fixture()
    workspace = attrs[:workspace] || workspace_fixture(user)

    {:ok, session} =
      %Jarga.Documents.ChatSession{}
      |> Jarga.Documents.ChatSession.changeset(%{
        user_id: user.id,
        workspace_id: workspace.id,
        title: attrs[:title],
        project_id: attrs[:project_id]
      })
      |> Repo.insert()

    session
  end

  @doc """
  Generate a chat message.
  """
  def chat_message_fixture(attrs \\ %{}) do
    session = attrs[:chat_session] || chat_session_fixture()

    {:ok, message} =
      %Jarga.Documents.ChatMessage{}
      |> Jarga.Documents.ChatMessage.changeset(%{
        chat_session_id: session.id,
        role: attrs[:role] || "user",
        content: attrs[:content] || "Test message content",
        context_chunks: attrs[:context_chunks] || []
      })
      |> Repo.insert()

    message
  end
end
