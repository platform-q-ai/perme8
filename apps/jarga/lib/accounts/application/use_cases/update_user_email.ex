defmodule Jarga.Accounts.Application.UseCases.UpdateUserEmail do
  @moduledoc """
  Use case for updating a user's email address.

  ## Business Rules

  - User must provide a valid change email token
  - Token must not be expired
  - Email must be valid and not already taken
  - All tokens for the old email context are deleted after successful update

  ## Responsibilities

  - Verify the change email token
  - Update the user's email
  - Delete all tokens for the old email context
  - Execute all operations in a transaction
  """

  @behaviour Jarga.Accounts.Application.UseCases.UseCase

  alias Jarga.Accounts.Infrastructure.Schemas.UserSchema
  alias Jarga.Accounts.Infrastructure.Queries.Queries
  alias Jarga.Accounts.Infrastructure.Repositories.{UserRepository, UserTokenRepository}

  @doc """
  Executes the update user email use case.

  ## Parameters

  - `params` - Map containing:
    - `:user` - The user whose email to update
    - `:token` - The email change verification token

  - `opts` - Keyword list of options:
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

    transaction_fn = Keyword.get(opts, :transaction_fn, &Jarga.Repo.unwrap_transaction/1)
    context = "change:#{user.email}"

    transaction_fn.(fn ->
      with {:ok, query} <- Queries.verify_change_email_token_query(token, context),
           user_token when not is_nil(user_token) <- UserTokenRepository.get_one(query),
           {:ok, user} <-
             UserRepository.update_changeset(
               UserSchema.email_changeset(user, %{email: user_token.sent_to})
             ),
           {_count, _result} <-
             UserTokenRepository.delete_all(Queries.tokens_for_user_and_context(user.id, context)) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end
end
