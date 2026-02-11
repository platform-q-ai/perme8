defmodule Identity.Application.UseCases.ResetUserPassword do
  @moduledoc """
  Use case for resetting a user's password via a reset token.

  ## Business Rules

  - Token must be valid and not expired (1 hour validity)
  - Token must match the user's current email
  - Password must meet format requirements
  - Password is hashed using PasswordService before storage
  - ALL user tokens are deleted after password reset for security
  - This invalidates all existing sessions
  - Operation is executed in a transaction for atomicity

  ## Dependency Injection

  This use case accepts the following dependencies via opts:
  - `:repo` - Ecto.Repo module (default: Identity.Repo)
  - `:queries` - Queries module (default: Infrastructure.Queries.TokenQueries)
  - `:user_schema` - UserSchema module (default: Infrastructure.Schemas.UserSchema)
  - `:user_repo` - UserRepository module (default: Infrastructure.Repositories.UserRepository)
  - `:user_token_repo` - UserTokenRepository module (default: Infrastructure.Repositories.UserTokenRepository)
  - `:password_service` - Password service function (default: PasswordService.hash_password/1)
  - `:transaction_fn` - Function to execute transaction (default: repo.unwrap_transaction/1)

  ## Responsibilities

  - Verify the reset token is valid
  - Validate password attributes (length, format, confirmation)
  - Hash the new password using PasswordService
  - Update the user record with new hashed password
  - Delete all user tokens for security
  """

  @behaviour Identity.Application.UseCases.UseCase

  import Ecto.Changeset, only: [get_change: 2, put_change: 3, delete_change: 2]

  alias Identity.Application.Services.PasswordService

  # Default implementations - can be overridden via opts for testing
  @default_repo Identity.Repo
  @default_queries Identity.Infrastructure.Queries.TokenQueries
  @default_user_schema Identity.Infrastructure.Schemas.UserSchema
  @default_user_repo Identity.Infrastructure.Repositories.UserRepository
  @default_user_token_repo Identity.Infrastructure.Repositories.UserTokenRepository

  @doc """
  Executes the reset user password use case.

  ## Parameters

  - `params` - Map containing:
    - `:token` - The reset password token
    - `:attrs` - Password attributes (password, password_confirmation)

  - `opts` - Keyword list of options for dependency injection

  ## Returns

  - `{:ok, user}` - Password reset successfully
  - `{:error, :invalid_token}` - Token is invalid or expired
  - `{:error, changeset}` - Password validation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{token: token, attrs: attrs} = params

    repo = Keyword.get(opts, :repo, @default_repo)
    queries = Keyword.get(opts, :queries, @default_queries)
    user_schema = Keyword.get(opts, :user_schema, @default_user_schema)
    user_repo = Keyword.get(opts, :user_repo, @default_user_repo)
    user_token_repo = Keyword.get(opts, :user_token_repo, @default_user_token_repo)
    password_service = Keyword.get(opts, :password_service, &PasswordService.hash_password/1)
    transaction_fn = Keyword.get(opts, :transaction_fn, &repo.unwrap_transaction/1)

    # First, verify the token and get the user
    with {:ok, query} <- queries.verify_reset_password_token_query(token),
         user_schema_record when not is_nil(user_schema_record) <- repo.one(query) do
      # Validate password attributes
      changeset = user_schema.password_changeset(user_schema_record, attrs)

      # If changeset is valid and has a password, hash it
      changeset_with_hashed_password =
        if changeset.valid? && get_change(changeset, :password) do
          password = get_change(changeset, :password)

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

      update_password_and_delete_tokens(changeset_with_hashed_password, deps)
    else
      :error -> {:error, :invalid_token}
      nil -> {:error, :invalid_token}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helper to update password and delete all tokens in a transaction
  defp update_password_and_delete_tokens(changeset, deps) do
    %{
      repo: repo,
      queries: queries,
      user_repo: user_repo,
      user_token_repo: user_token_repo,
      transaction_fn: transaction_fn
    } = deps

    transaction_fn.(fn ->
      with {:ok, user} <- user_repo.update_changeset(changeset, repo) do
        # Retrieve all tokens before deletion
        tokens_to_expire = user_token_repo.all_by_user_id(user.id, repo)

        # Delete all tokens in a single query
        user_token_repo.delete_all(
          queries.tokens_by_ids(Enum.map(tokens_to_expire, & &1.id)),
          repo
        )

        {:ok, user}
      end
    end)
  end
end
