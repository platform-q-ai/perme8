defmodule Jarga.AgentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Jarga.Agents` context.
  """

  use Boundary,
    top_level?: true,
    deps: [Jarga.Agents, Jarga.Repo, Jarga.AccountsFixtures, Jarga.WorkspacesFixtures],
    exports: []

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Jarga.Repo
  alias Jarga.Agents.Domain.Entities.ChatSession
  alias Jarga.Agents.Domain.Entities.ChatMessage

  @doc """
  Generate a user agent.
  """
  def user_agent_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || user_fixture().id

    agent_params = %{
      user_id: user_id,
      name: attrs[:name] || "Test Agent",
      description: attrs[:description],
      system_prompt: attrs[:system_prompt],
      model: attrs[:model],
      temperature: attrs[:temperature],
      visibility: attrs[:visibility] || "PRIVATE",
      enabled: Map.get(attrs, :enabled, true)
    }

    {:ok, agent} = Jarga.Agents.create_user_agent(agent_params)
    agent
  end

  @doc """
  Convenience alias for agent_fixture/2.
  Accepts a user as first parameter and attrs as second parameter.
  """
  def agent_fixture(user, attrs \\ %{}) do
    attrs_with_defaults =
      attrs
      |> Map.put(:user_id, user.id)
      |> Map.put_new(:temperature, 0.7)

    user_agent_fixture(attrs_with_defaults)
  end

  @doc """
  Generate a chat session.
  """
  def chat_session_fixture(attrs \\ %{}) do
    user = attrs[:user] || user_fixture()
    workspace = attrs[:workspace] || workspace_fixture(user)

    {:ok, session} =
      %ChatSession{}
      |> ChatSession.changeset(%{
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
      %ChatMessage{}
      |> ChatMessage.changeset(%{
        chat_session_id: session.id,
        role: attrs[:role] || "user",
        content: attrs[:content] || "Test message content",
        context_chunks: attrs[:context_chunks] || []
      })
      |> Repo.insert()

    message
  end
end
