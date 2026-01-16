defmodule Jarga.Accounts.Application.UseCases.RevokeApiKey do
  @moduledoc """
  Use case for revoking (deactivating) API keys.
  """

  alias Jarga.Accounts.Domain.Policies.ApiKeyPolicy
  alias Jarga.Accounts.Infrastructure.Repositories.ApiKeyRepository

  @doc """
  Executes the revoke API key use case.

  ## Parameters

    - `user_id` - The user ID performing the revoke
    - `api_key_id` - The API key ID to revoke
    - `opts` - Options:
      - `repo` - Ecto.Repo (defaults to Jarga.Repo)

  ## Returns

    `{:ok, api_key}` on success
    `{:error, :not_found}` if API key doesn't exist
    `{:error, :forbidden}` if user doesn't own the API key

  """
  def execute(user_id, api_key_id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Jarga.Repo)

    with {:ok, api_key} <- ApiKeyRepository.get_by_id(repo, api_key_id),
         :ok <- authorize_management(api_key, user_id) do
      ApiKeyRepository.update(repo, api_key.id, %{is_active: false})
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
