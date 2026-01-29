defmodule Jarga.Accounts.Application.UseCases.UpdateUserEmail do
  @moduledoc """
  Use case for updating a user's email address.

  ## Business Rules

  - User must provide a valid change email token
  - Token must not be expired
  - Email must be valid and not already taken
  - All tokens for the old email context are deleted after successful update

  ## Dependency Injection

  This use case accepts the following dependencies via opts:
  - `:queries` - Queries module (default: Infrastructure.Queries.Queries)
  - `:user_schema` - UserSchema module (default: Infrastructure.Schemas.UserSchema)
  - `:user_repo` - UserRepository module (default: Infrastructure.Repositories.UserRepository)
  - `:user_token_repo` - UserTokenRepository module (default: Infrastructure.Repositories.UserTokenRepository)
  - `:transaction_fn` - Function to execute transaction (default: &Jarga.Repo.unwrap_transaction/1)

  ## Responsibilities

  - Verify the change email token
  - Update the user's email
  - Delete all tokens for the old email context
  - Execute all operations in a transaction
  """

  @behaviour Jarga.Accounts.Application.UseCases.UseCase

  # Default implementations - can be overridden via opts for testing
  @default_repo Jarga.Repo
  @default_queries Jarga.Accounts.Infrastructure.Queries.Queries
  @default_user_schema Jarga.Accounts.Infrastructure.Schemas.UserSchema
  @default_user_repo Jarga.Accounts.Infrastructure.Repositories.UserRepository
  @default_user_token_repo Jarga.Accounts.Infrastructure.Repositories.UserTokenRepository

  @doc """
  Executes the update user email use case.

  ## Parameters

  - `params` - Map containing:
    - `:user` - The user whose email to update
    - `:token` - The email change verification token

  - `opts` - Keyword list of options:
    - `:queries` - Queries module (default: Infrastructure.Queries.Queries)
    - `:user_schema` - UserSchema module (default: Infrastructure.Schemas.UserSchema)
    - `:user_repo` - UserRepository module (default: Infrastructure.Repositories.UserRepository)
    - `:user_token_repo` - UserTokenRepository module (default: Infrastructure.Repositories.UserTokenRepository)
    - `:transaction_fn` - Function to execute transaction (default: &Jarga.Repo.unwrap_transaction/1)

  ## Returns

  - `{:ok, user}` - Email updated successfully
  - `{:error, :transaction_aborted}` - Operation failed
  """
  @impl true
  def execute(params, opts \\ []) do
    %{
      user: user,
      token: token
    } = params

    repo = Keyword.get(opts, :repo, @default_repo)
    queries = Keyword.get(opts, :queries, @default_queries)
    user_schema = Keyword.get(opts, :user_schema, @default_user_schema)
    user_repo = Keyword.get(opts, :user_repo, @default_user_repo)
    user_token_repo = Keyword.get(opts, :user_token_repo, @default_user_token_repo)
    transaction_fn = Keyword.get(opts, :transaction_fn, &repo.unwrap_transaction/1)

    context = "change:#{user.email}"

    transaction_fn.(fn ->
      with {:ok, query} <- queries.verify_change_email_token_query(token, context),
           user_token when not is_nil(user_token) <- user_token_repo.get_one(query),
           {:ok, user} <-
             user_repo.update_changeset(
               user_schema.email_changeset(user, %{email: user_token.sent_to})
             ),
           {_count, _result} <-
             user_token_repo.delete_all(queries.tokens_for_user_and_context(user.id, context)) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end
end
