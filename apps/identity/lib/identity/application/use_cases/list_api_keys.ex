defmodule Identity.Application.UseCases.ListApiKeys do
  @moduledoc """
  Use case for listing API keys for a user.

  ## Dependency Injection

  This use case accepts the following dependencies via opts:
  - `:repo` - Ecto.Repo module (default: Jarga.Repo)
  - `:api_key_repo` - ApiKeyRepository module (default: Infrastructure.Repositories.ApiKeyRepository)
  - `:is_active` - Filter by active status (true/false/nil for all)
  """

  # Default implementations - can be overridden via opts for testing
  @default_repo Jarga.Repo
  @default_api_key_repo Jarga.Accounts.Infrastructure.Repositories.ApiKeyRepository

  @doc """
  Executes the list API keys use case.

  ## Parameters

    - `user_id` - The user ID to list API keys for
    - `opts` - Options:
      - `:repo` - Ecto.Repo (defaults to Jarga.Repo)
      - `:api_key_repo` - ApiKeyRepository module (default: Infrastructure.Repositories.ApiKeyRepository)
      - `:is_active` - Filter by active status (true/false/nil for all)

  ## Returns

    `{:ok, api_keys}` on success

  """
  def execute(user_id, opts \\ []) do
    repo = Keyword.get(opts, :repo, @default_repo)
    api_key_repo = Keyword.get(opts, :api_key_repo, @default_api_key_repo)
    is_active_filter = Keyword.get(opts, :is_active)

    {:ok, api_keys} = api_key_repo.list_by_user_id(repo, user_id)

    filtered_keys =
      case is_active_filter do
        true -> Enum.filter(api_keys, & &1.is_active)
        false -> Enum.filter(api_keys, &(!&1.is_active))
        _ -> api_keys
      end

    {:ok, filtered_keys}
  end
end
