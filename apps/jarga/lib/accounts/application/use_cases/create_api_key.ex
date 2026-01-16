defmodule Jarga.Accounts.Application.UseCases.CreateApiKey do
  @moduledoc """
  Use case for creating API keys.
  """

  alias Jarga.Accounts.Infrastructure.Repositories.ApiKeyRepository
  alias Jarga.Accounts.Infrastructure.Schemas.ApiKeySchema
  alias Jarga.Accounts.Application.Services.ApiKeyTokenService

  @doc """
  Executes the create API key use case.
  """
  def execute(user_id, attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo, Jarga.Repo)
    workspaces = Keyword.get(opts, :workspaces, Jarga.Workspaces)

    workspace_access = Map.get(attrs, :workspace_access, [])

    with {:ok, validated_access} <-
           validate_workspace_access(workspaces, user_id, workspace_access),
         api_key_attrs <- build_api_key_attrs(user_id, attrs, validated_access),
         {:ok, result} <- create_api_key_in_transaction(repo, api_key_attrs) do
      {:ok, result}
    else
      {:error, :workspace_access} -> {:error, :forbidden}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_api_key_attrs(user_id, attrs, validated_access) do
    plain_token = ApiKeyTokenService.generate_token()
    hashed_token = ApiKeyTokenService.hash_token(plain_token)

    api_key_attrs = %{
      name: attrs[:name],
      description: attrs[:description],
      hashed_token: hashed_token,
      user_id: user_id,
      workspace_access: validated_access,
      is_active: true
    }

    {api_key_attrs, plain_token}
  end

  defp create_api_key_in_transaction(repo, {api_key_attrs, plain_token}) do
    repo.transaction(fn ->
      case ApiKeyRepository.insert(repo, api_key_attrs) do
        {:ok, schema} ->
          api_key = ApiKeySchema.to_entity(schema)
          {api_key, plain_token}

        {:error, changeset} ->
          repo.rollback(changeset)
      end
    end)
  end

  defp validate_workspace_access(_workspaces, _user_id, []), do: {:ok, []}

  defp validate_workspace_access(workspaces, user_id, workspace_access) do
    results = Enum.map(workspace_access, &check_membership(workspaces, user_id, &1))
    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      {:ok, Enum.map(results, fn {:ok, slug} -> slug end)}
    else
      {:error, :workspace_access}
    end
  end

  defp check_membership(workspaces, user_id, workspace_slug) do
    if workspaces.member_by_slug?(user_id, workspace_slug) do
      {:ok, workspace_slug}
    else
      {:error, workspace_slug}
    end
  end
end
