defmodule Jarga.Workspaces.Api.Helpers do
  @moduledoc """
  Shared helper functions for Workspace API step definitions.
  """

  alias Ecto.Adapters.SQL.Sandbox
  alias Jarga.Accounts.Application.Services.ApiKeyTokenService
  alias Jarga.Accounts.Infrastructure.Repositories.ApiKeyRepository
  alias Jarga.Accounts.Infrastructure.Schemas.ApiKeySchema

  def ensure_sandbox_checkout do
    case Sandbox.checkout(Jarga.Repo) do
      :ok ->
        Sandbox.mode(Jarga.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end
  end

  @doc """
  Builds a connection with sandbox metadata header for API tests.

  This is critical for API tests using Phoenix.ConnTest - without the sandbox
  metadata header, the API endpoint runs in a different DB connection and
  can't see data created in the test process.
  """
  def build_conn_with_sandbox do
    # Get sandbox metadata for the test process
    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Jarga.Repo, self())
    encoded_metadata = Phoenix.Ecto.SQL.Sandbox.encode_metadata(metadata)

    Phoenix.ConnTest.build_conn()
    |> Plug.Conn.put_req_header("user-agent", encoded_metadata)
  end

  @doc """
  Parses workspace access from comma-separated string.
  """
  def parse_workspace_access(nil), do: []
  def parse_workspace_access(""), do: []

  def parse_workspace_access(workspace_access_str) do
    workspace_access_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  @doc """
  Creates an API key directly in the database with a plain token.
  Returns {api_key_entity, plain_token}.
  """
  def create_api_key_fixture(user_id, attrs) do
    plain_token = attrs[:token] || ApiKeyTokenService.generate_token()
    hashed_token = ApiKeyTokenService.hash_token(plain_token)

    api_key_attrs = %{
      name: attrs[:name] || "Test API Key",
      description: attrs[:description],
      hashed_token: hashed_token,
      user_id: user_id,
      workspace_access: attrs[:workspace_access] || [],
      is_active: Map.get(attrs, :is_active, true)
    }

    {:ok, schema} =
      ApiKeyRepository.insert(
        Jarga.Repo,
        api_key_attrs
      )

    api_key = ApiKeySchema.to_entity(schema)
    {api_key, plain_token}
  end

  @doc """
  Gets workspace from context by slug.
  """
  def get_workspace_by_slug(context, slug) do
    Map.get(context[:workspaces] || %{}, slug) ||
      Map.get(context[:additional_workspaces] || %{}, slug) ||
      if(context[:workspace] && context[:workspace].slug == slug, do: context[:workspace])
  end
end
