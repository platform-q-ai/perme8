defmodule Jarga.Accounts.Application.UseCases.VerifyApiKey do
  @moduledoc """
  Use case for verifying API key tokens.
  """

  alias Jarga.Accounts.Infrastructure.Repositories.ApiKeyRepository
  alias Jarga.Accounts.Application.Services.ApiKeyTokenService

  @doc """
  Executes the verify API key use case.

  ## Parameters

    - `plain_token` - The plain API key token to verify
    - `opts` - Options:
      - `repo` - Ecto.Repo (defaults to Jarga.Repo)

  ## Returns

    `{:ok, api_key}` on success
    `{:error, :invalid}` if token doesn't match or key doesn't exist
    `{:error, :inactive}` if key exists but is inactive

  """
  def execute(plain_token, opts \\ []) do
    repo = Keyword.get(opts, :repo, Jarga.Repo)
    hashed_token = ApiKeyTokenService.hash_token(plain_token)

    with {:ok, api_key} <- ApiKeyRepository.get_by_hashed_token(repo, hashed_token),
         :ok <- check_active(api_key),
         :ok <- verify_token_match(plain_token, api_key.hashed_token) do
      {:ok, api_key}
    else
      {:error, :not_found} -> {:error, :invalid}
      {:error, reason} -> {:error, reason}
    end
  end

  defp check_active(api_key) do
    if api_key.is_active, do: :ok, else: {:error, :inactive}
  end

  defp verify_token_match(plain_token, hashed_token) do
    # Double-verify the token (prevents timing attacks)
    if ApiKeyTokenService.verify_token(plain_token, hashed_token) do
      :ok
    else
      {:error, :invalid}
    end
  end
end
