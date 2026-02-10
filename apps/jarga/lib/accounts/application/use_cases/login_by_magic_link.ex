defmodule Jarga.Accounts.Application.UseCases.LoginByMagicLink do
  @moduledoc """
  Use case for logging in a user via a magic link token.

  ## Business Rules

  There are three cases to consider based on user state:

  ### Case 1: Confirmed user (with or without password)
  - User has already confirmed their email
  - Delete only the magic link token
  - Return the user with empty expired tokens list

  ### Case 2: Unconfirmed user without password
  - User has not confirmed their email and no password is set
  - Confirm the user
  - Delete ALL tokens (including any session tokens)
  - Return the user with list of expired tokens
  - This is the strictest case for security

  ### Case 3: Unconfirmed user with password
  - User registered with password but hasn't confirmed email yet
  - Confirm the user when they click the magic link (proves email ownership)
  - Delete only the magic link token
  - Keep other tokens (like session tokens) intact

  ## Dependency Injection

  This use case accepts the following dependencies via opts:
  - `:repo` - Ecto.Repo module (default: Jarga.Repo)
  - `:queries` - Queries module (default: Infrastructure.Queries.Queries)
  - `:user_schema` - UserSchema module (default: Infrastructure.Schemas.UserSchema)
  - `:user_repo` - UserRepository module (default: Infrastructure.Repositories.UserRepository)
  - `:user_token_repo` - UserTokenRepository module (default: Infrastructure.Repositories.UserTokenRepository)
  - `:transaction_fn` - Function to execute transaction (default: repo.unwrap_transaction/1)

  ## Responsibilities

  - Verify the magic link token exists and is valid
  - Determine which case applies based on user state
  - Confirm user if needed
  - Delete appropriate tokens based on the case
  - Execute all operations in a transaction for atomicity
  """

  @behaviour Jarga.Accounts.Application.UseCases.UseCase

  alias Jarga.Accounts.Domain.Entities.User

  # Default implementations - can be overridden via opts for testing
  @default_repo Identity.Repo
  @default_queries Jarga.Accounts.Infrastructure.Queries.Queries
  @default_user_schema Jarga.Accounts.Infrastructure.Schemas.UserSchema
  @default_user_repo Jarga.Accounts.Infrastructure.Repositories.UserRepository
  @default_user_token_repo Jarga.Accounts.Infrastructure.Repositories.UserTokenRepository

  @doc """
  Executes the login by magic link use case.

  ## Parameters

  - `params` - Map containing:
    - `:token` - The magic link token (string)

  - `opts` - Keyword list of options:
    - `:repo` - Repository module (default: Jarga.Repo)
    - `:queries` - Queries module (default: Infrastructure.Queries.Queries)
    - `:user_schema` - UserSchema module (default: Infrastructure.Schemas.UserSchema)
    - `:user_repo` - UserRepository module (default: Infrastructure.Repositories.UserRepository)
    - `:user_token_repo` - UserTokenRepository module (default: Infrastructure.Repositories.UserTokenRepository)
    - `:transaction_fn` - Function to execute transaction (default: repo.unwrap_transaction/1)

  ## Returns

  - `{:ok, {user, expired_tokens}}` - User logged in successfully
  - `{:error, :invalid_token}` - Token format is invalid
  - `{:error, :not_found}` - Token not found in database
  """
  @impl true
  def execute(params, opts \\ []) do
    %{token: token} = params
    repo = Keyword.get(opts, :repo, @default_repo)
    queries = Keyword.get(opts, :queries, @default_queries)
    user_schema = Keyword.get(opts, :user_schema, @default_user_schema)
    user_repo = Keyword.get(opts, :user_repo, @default_user_repo)
    user_token_repo = Keyword.get(opts, :user_token_repo, @default_user_token_repo)
    transaction_fn = Keyword.get(opts, :transaction_fn, &repo.unwrap_transaction/1)

    deps = %{
      repo: repo,
      queries: queries,
      user_schema: user_schema,
      user_repo: user_repo,
      user_token_repo: user_token_repo,
      transaction_fn: transaction_fn
    }

    with {:ok, query} <- queries.verify_magic_link_token_query(token),
         result when not is_nil(result) <- repo.one(query) do
      handle_magic_link_result(result, deps)
    else
      nil -> {:error, :not_found}
      :error -> {:error, :invalid_token}
    end
  end

  # Case 3: Unconfirmed user with password - confirm and delete only the magic link token
  defp handle_magic_link_result(
         {%{confirmed_at: nil, hashed_password: hash} = user, token},
         deps
       )
       when not is_nil(hash) do
    %{
      repo: repo,
      user_schema: user_schema,
      user_repo: user_repo,
      user_token_repo: user_token_repo
    } = deps

    # For password-based registration, we confirm the user when they click the magic link
    # This is safe because they have proven ownership of the email
    case user_repo.update_changeset(user_schema.confirm_changeset(user), repo) do
      {:ok, confirmed_user} ->
        # Delete only the magic link token after confirmation
        user_token_repo.delete!(token, repo)
        {:ok, {confirmed_user, []}}

      error ->
        error
    end
  end

  # Case 2: Unconfirmed user without password - confirm and delete ALL tokens
  defp handle_magic_link_result(
         {%{confirmed_at: nil} = user, _token},
         deps
       ) do
    %{
      repo: repo,
      queries: queries,
      user_schema: user_schema,
      user_repo: user_repo,
      user_token_repo: user_token_repo,
      transaction_fn: transaction_fn
    } = deps

    transaction_fn.(fn ->
      with {:ok, user} <-
             user_repo.update_changeset(user_schema.confirm_changeset(user), repo) do
        tokens_to_expire = user_token_repo.all_by_user_id(user.id, repo)

        user_token_repo.delete_all(
          queries.tokens_by_ids(Enum.map(tokens_to_expire, & &1.id)),
          repo
        )

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end

  # Case 1: Already confirmed user - just delete the token
  defp handle_magic_link_result({user_schema, token}, deps) do
    %{repo: repo, user_token_repo: user_token_repo} = deps

    user_token_repo.delete!(token, repo)
    user = User.from_schema(user_schema)
    {:ok, {user, []}}
  end
end
