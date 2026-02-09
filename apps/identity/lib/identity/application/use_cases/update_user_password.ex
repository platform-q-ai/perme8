defmodule Identity.Application.UseCases.UpdateUserPassword do
  @moduledoc """
  Use case for updating a user's password.

  ## Business Rules

  - User must provide a valid new password that meets format requirements
  - Password is hashed using PasswordService before storage
  - ALL user tokens are deleted after password update for security
  - This invalidates all existing sessions and magic links
  - Operation is executed in a transaction for atomicity

  ## Dependency Injection

  This use case accepts the following dependencies via opts:
  - `:repo` - Ecto.Repo module (default: Jarga.Repo)
  - `:queries` - Queries module (default: Infrastructure.Queries.Queries)
  - `:user_schema` - UserSchema module (default: Infrastructure.Schemas.UserSchema)
  - `:user_repo` - UserRepository module (default: Infrastructure.Repositories.UserRepository)
  - `:user_token_repo` - UserTokenRepository module (default: Infrastructure.Repositories.UserTokenRepository)
  - `:password_service` - Password service module or function (default: PasswordService.hash_password/1)
  - `:transaction_fn` - Function to execute transaction (default: repo.unwrap_transaction/1)

  ## Responsibilities

  - Validate password attributes (length, format, confirmation)
  - Hash the new password using PasswordService
  - Update the user record with new hashed password
  - Retrieve all user tokens before deletion
  - Delete all user tokens in a single operation
  - Return expired tokens list for session management
  """

  @behaviour Identity.Application.UseCases.UseCase

  import Ecto.Changeset, only: [get_change: 2, put_change: 3, delete_change: 2]

  alias Identity.Application.Services.PasswordService

  # Default implementations - can be overridden via opts for testing
  @default_repo Jarga.Repo
  @default_queries Jarga.Accounts.Infrastructure.Queries.Queries
  @default_user_schema Jarga.Accounts.Infrastructure.Schemas.UserSchema
  @default_user_repo Jarga.Accounts.Infrastructure.Repositories.UserRepository
  @default_user_token_repo Jarga.Accounts.Infrastructure.Repositories.UserTokenRepository

  @doc """
  Executes the update user password use case.

  ## Parameters

  - `params` - Map containing:
    - `:user` - The user to update
    - `:attrs` - Password attributes (password, password_confirmation)

  - `opts` - Keyword list of options:
    - `:repo` - Repository module (default: Jarga.Repo)
    - `:queries` - Queries module (default: Infrastructure.Queries.Queries)
    - `:user_schema` - UserSchema module (default: Infrastructure.Schemas.UserSchema)
    - `:user_repo` - UserRepository module (default: Infrastructure.Repositories.UserRepository)
    - `:user_token_repo` - UserTokenRepository module (default: Infrastructure.Repositories.UserTokenRepository)
    - `:password_service` - Password service module or function (default: PasswordService.hash_password/1)
    - `:transaction_fn` - Function to execute transaction (default: repo.unwrap_transaction/1)

  ## Returns

  - `{:ok, {user, expired_tokens}}` - Password updated successfully with list of expired tokens
  - `{:error, changeset}` - Validation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{user: user, attrs: attrs} = params

    repo = Keyword.get(opts, :repo, @default_repo)
    queries = Keyword.get(opts, :queries, @default_queries)
    user_schema = Keyword.get(opts, :user_schema, @default_user_schema)
    user_repo = Keyword.get(opts, :user_repo, @default_user_repo)
    user_token_repo = Keyword.get(opts, :user_token_repo, @default_user_token_repo)
    password_service = Keyword.get(opts, :password_service, &PasswordService.hash_password/1)
    transaction_fn = Keyword.get(opts, :transaction_fn, &repo.unwrap_transaction/1)

    # Validate password attributes
    changeset = user_schema.password_changeset(user, attrs)

    # If changeset is valid and has a password, hash it
    changeset_with_hashed_password =
      if changeset.valid? && get_change(changeset, :password) do
        password = get_change(changeset, :password)

        # Support both module and function for password service
        hashed_password =
          if is_function(password_service, 1) do
            password_service.(password)
          else
            password_service.hash_password(password)
          end

        changeset
        |> put_change(:hashed_password, hashed_password)
        |> delete_change(:password)
      else
        changeset
      end

    deps = %{
      repo: repo,
      queries: queries,
      user_repo: user_repo,
      user_token_repo: user_token_repo,
      transaction_fn: transaction_fn
    }

    # Execute update and token deletion in transaction
    update_user_and_delete_all_tokens(changeset_with_hashed_password, deps)
  end

  # Private helper to update user and delete all tokens in a transaction
  defp update_user_and_delete_all_tokens(changeset, deps) do
    %{
      repo: repo,
      queries: queries,
      user_repo: user_repo,
      user_token_repo: user_token_repo,
      transaction_fn: transaction_fn
    } = deps

    transaction_fn.(fn ->
      with {:ok, user} <- user_repo.update_changeset(changeset, repo) do
        # Retrieve all tokens before deletion (to return expired list)
        tokens_to_expire = user_token_repo.all_by_user_id(user.id, repo)

        # Delete all tokens in a single query
        user_token_repo.delete_all(
          queries.tokens_by_ids(Enum.map(tokens_to_expire, & &1.id)),
          repo
        )

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
