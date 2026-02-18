defmodule Agents.Test.JargaFixtures do
  @moduledoc "Shared test fixtures for Jarga MCP tool tests."

  @workspace_id "ws-test-jarga-001"
  @user_id "user-test-jarga-001"

  def workspace_id, do: @workspace_id
  def user_id, do: @user_id
  def unique_id, do: Ecto.UUID.generate()

  def workspace_map(overrides \\ %{}) do
    Map.merge(
      %{
        id: unique_id(),
        name: "Test Workspace",
        slug: "test-workspace"
      },
      overrides
    )
  end

  def project_map(overrides \\ %{}) do
    Map.merge(
      %{
        id: unique_id(),
        name: "Test Project",
        slug: "test-project",
        description: "A test project",
        workspace_id: @workspace_id
      },
      overrides
    )
  end

  def document_map(overrides \\ %{}) do
    Map.merge(
      %{
        id: unique_id(),
        title: "Test Document",
        slug: "test-document",
        is_public: false,
        workspace_id: @workspace_id
      },
      overrides
    )
  end
end
