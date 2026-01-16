defmodule Jarga.Accounts.Application.UseCases.ListApiKeys do
  @moduledoc """
  Use case for listing API keys for a user.
  """

  alias Jarga.Accounts.Infrastructure.Repositories.ApiKeyRepository

  @doc """
  Executes the list API keys use case.

  ## Parameters

    - `user_id` - The user ID to list API keys for
    - `opts` - Options:
      - `repo` - Ecto.Repo (defaults to Jarga.Repo)
      - `is_active` - Filter by active status (true/false/nil for all)

  ## Returns

    `{:ok, api_keys}` on success

  """
  def execute(user_id, opts \\ []) do
    repo = Keyword.get(opts, :repo, Jarga.Repo)
    is_active_filter = Keyword.get(opts, :is_active)

    {:ok, api_keys} = ApiKeyRepository.list_by_user_id(repo, user_id)

    filtered_keys =
      case is_active_filter do
        true -> Enum.filter(api_keys, & &1.is_active)
        false -> Enum.filter(api_keys, &(!&1.is_active))
        _ -> api_keys
      end

    {:ok, filtered_keys}
  end
end
