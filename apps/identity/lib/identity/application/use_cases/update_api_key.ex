defmodule Identity.Application.UseCases.UpdateApiKey do
  @moduledoc """
  Use case for updating API keys.

  ## Dependency Injection

  This use case accepts the following dependencies via opts:
  - `:repo` - Ecto.Repo module (default: Jarga.Repo)
  - `:api_key_repo` - ApiKeyRepository module (default: Infrastructure.Repositories.ApiKeyRepository)
  - `:workspaces` - Workspaces context for validation (default: Jarga.Workspaces)
  """

  alias Identity.Domain.Policies.ApiKeyPolicy

  # Default implementations - can be overridden via opts for testing
  @default_repo Jarga.Repo
  @default_api_key_repo Jarga.Accounts.Infrastructure.Repositories.ApiKeyRepository
  @default_workspaces Jarga.Workspaces

  @doc """
  Executes the update API key use case.

  ## Parameters

    - `user_id` - The user ID performing the update
    - `api_key_id` - The API key ID to update
    - `attrs` - Map with fields to update (name, description, workspace_access)
    - `opts` - Options:
      - `:repo` - Ecto.Repo (defaults to Jarga.Repo)
      - `:api_key_repo` - ApiKeyRepository module (default: Infrastructure.Repositories.ApiKeyRepository)
      - `:workspaces` - Workspaces context for validation (default: Jarga.Workspaces)

  ## Returns

    `{:ok, api_key}` on success
    `{:error, :not_found}` if API key doesn't exist
    `{:error, :forbidden}` if user doesn't own the API key
    `{:error, :forbidden}` if user doesn't have access to specified workspaces
    `{:error, changeset}` on validation error

  """
  def execute(user_id, api_key_id, attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo, @default_repo)
    api_key_repo = Keyword.get(opts, :api_key_repo, @default_api_key_repo)
    workspaces = Keyword.get(opts, :workspaces, @default_workspaces)
    workspace_access = Map.get(attrs, :workspace_access)

    with {:ok, api_key} <- api_key_repo.get_by_id(repo, api_key_id),
         :ok <- authorize_management(api_key, user_id),
         :ok <- validate_workspace_access(workspaces, user_id, workspace_access) do
      update_attrs = Map.take(attrs, [:name, :description, :workspace_access])
      api_key_repo.update(repo, api_key.id, update_attrs)
    else
      {:error, :not_found} -> {:error, :not_found}
      {:error, :forbidden} -> {:error, :forbidden}
      {:error, :workspace_access} -> {:error, :forbidden}
      {:error, reason} -> {:error, reason}
    end
  end

  defp authorize_management(api_key, user_id) do
    if ApiKeyPolicy.can_manage_api_key?(api_key, user_id) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  defp validate_workspace_access(_workspaces, _user_id, nil), do: :ok
  defp validate_workspace_access(_workspaces, _user_id, []), do: :ok

  defp validate_workspace_access(workspaces, user_id, workspace_access) do
    results = Enum.map(workspace_access, &check_membership(workspaces, user_id, &1))
    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors), do: :ok, else: {:error, :workspace_access}
  end

  defp check_membership(workspaces, user_id, workspace_slug) do
    if workspaces.member_by_slug?(user_id, workspace_slug) do
      {:ok, workspace_slug}
    else
      {:error, workspace_slug}
    end
  end
end
