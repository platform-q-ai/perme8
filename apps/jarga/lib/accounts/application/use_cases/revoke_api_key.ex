defmodule Jarga.Accounts.Application.UseCases.RevokeApiKey do
  @moduledoc """
  Use case for revoking (deactivating) API keys.

  ## Dependency Injection

  This use case accepts the following dependencies via opts:
  - `:repo` - Ecto.Repo module (default: Jarga.Repo)
  - `:api_key_repo` - ApiKeyRepository module (default: Infrastructure.Repositories.ApiKeyRepository)
  """

  alias Jarga.Accounts.Domain.Policies.ApiKeyPolicy

  # Default implementations - can be overridden via opts for testing
  @default_repo Identity.Repo
  @default_api_key_repo Jarga.Accounts.Infrastructure.Repositories.ApiKeyRepository

  @doc """
  Executes the revoke API key use case.

  ## Parameters

    - `user_id` - The user ID performing the revoke
    - `api_key_id` - The API key ID to revoke
    - `opts` - Options:
      - `:repo` - Ecto.Repo (defaults to Jarga.Repo)
      - `:api_key_repo` - ApiKeyRepository module (default: Infrastructure.Repositories.ApiKeyRepository)

  ## Returns

    `{:ok, api_key}` on success
    `{:error, :not_found}` if API key doesn't exist
    `{:error, :forbidden}` if user doesn't own the API key

  """
  def execute(user_id, api_key_id, opts \\ []) do
    repo = Keyword.get(opts, :repo, @default_repo)
    api_key_repo = Keyword.get(opts, :api_key_repo, @default_api_key_repo)

    with {:ok, api_key} <- api_key_repo.get_by_id(repo, api_key_id),
         :ok <- authorize_management(api_key, user_id) do
      api_key_repo.update(repo, api_key.id, %{is_active: false})
    end
  end

  defp authorize_management(api_key, user_id) do
    if ApiKeyPolicy.can_manage_api_key?(api_key, user_id) do
      :ok
    else
      {:error, :forbidden}
    end
  end
end
