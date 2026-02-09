defmodule Identity.Application.UseCases.GenerateSessionToken do
  @moduledoc """
  Use case for generating a session token for a user.

  ## Business Rules

  - Session token is generated using UserToken.build_session_token/1
  - Token is persisted in the database immediately
  - Token context is "session"
  - If user has authenticated_at timestamp, it's included in the token
  - Returns the encoded token binary for use in cookies/sessions

  ## Dependency Injection

  This use case accepts the following dependencies via opts:
  - `:repo` - Ecto.Repo module (default: Jarga.Repo)
  - `:user_token_repo` - UserTokenRepository module (default: Infrastructure.Repositories.UserTokenRepository)

  ## Responsibilities

  - Build session token with proper structure
  - Persist token in database
  - Return encoded token for session management
  """

  @behaviour Identity.Application.UseCases.UseCase

  alias Identity.Domain.Services.TokenBuilder

  # Default implementations - can be overridden via opts for testing
  @default_repo Jarga.Repo
  @default_user_token_repo Jarga.Accounts.Infrastructure.Repositories.UserTokenRepository

  @doc """
  Executes the generate session token use case.

  ## Parameters

  - `params` - Map containing:
    - `:user` - The user to generate a session token for

  - `opts` - Keyword list of options:
    - `:repo` - Repository module (default: Jarga.Repo)
    - `:user_token_repo` - UserTokenRepository module (default: Infrastructure.Repositories.UserTokenRepository)

  ## Returns

  - Binary token string that can be used for session management
  """
  @impl true
  def execute(params, opts \\ []) do
    %{user: user} = params

    repo = Keyword.get(opts, :repo, @default_repo)
    user_token_repo = Keyword.get(opts, :user_token_repo, @default_user_token_repo)

    # Build session token
    {token, user_token} = TokenBuilder.build_session_token(user)

    # Persist token in database
    user_token_repo.insert!(user_token, repo)

    # Return encoded token
    token
  end
end
