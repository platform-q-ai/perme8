defmodule Identity.Application.UseCases.VerifyApiKey do
  @moduledoc """
  Use case for verifying API key tokens.

  ## Dependency Injection

  This use case accepts the following dependencies via opts:
  - `:repo` - Ecto.Repo module (default: Jarga.Repo)
  - `:api_key_repo` - ApiKeyRepository module (default: Infrastructure.Repositories.ApiKeyRepository)
  - `:token_service` - Token service module (default: ApiKeyTokenService)
  """

  alias Identity.Application.Services.ApiKeyTokenService

  # Default implementations - can be overridden via opts for testing
  @default_repo Jarga.Repo
  @default_api_key_repo Jarga.Accounts.Infrastructure.Repositories.ApiKeyRepository
  @default_token_service ApiKeyTokenService

  @doc """
  Executes the verify API key use case.

  ## Parameters

    - `plain_token` - The plain API key token to verify
    - `opts` - Options:
      - `:repo` - Ecto.Repo (defaults to Jarga.Repo)
      - `:api_key_repo` - ApiKeyRepository module (default: Infrastructure.Repositories.ApiKeyRepository)
      - `:token_service` - Token service module (default: ApiKeyTokenService)

  ## Returns

    `{:ok, api_key}` on success
    `{:error, :invalid}` if token doesn't match or key doesn't exist
    `{:error, :inactive}` if key exists but is inactive

  """
  def execute(plain_token, opts \\ []) do
    repo = Keyword.get(opts, :repo, @default_repo)
    api_key_repo = Keyword.get(opts, :api_key_repo, @default_api_key_repo)
    token_service = Keyword.get(opts, :token_service, @default_token_service)

    hashed_token = token_service.hash_token(plain_token)

    with {:ok, api_key} <- api_key_repo.get_by_hashed_token(repo, hashed_token),
         :ok <- check_active(api_key),
         :ok <- verify_token_match(token_service, plain_token, api_key.hashed_token) do
      {:ok, api_key}
    else
      {:error, :not_found} -> {:error, :invalid}
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_active(api_key) do
    if api_key.is_active, do: :ok, else: {:error, :inactive}
  end

  defp verify_token_match(token_service, plain_token, hashed_token) do
    # Double-verify the token (prevents timing attacks)
    if token_service.verify_token(plain_token, hashed_token) do
      :ok
    else
      {:error, :invalid}
    end
  end
end
