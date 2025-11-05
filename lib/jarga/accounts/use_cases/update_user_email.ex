defmodule Jarga.Accounts.UseCases.UpdateUserEmail do
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

  @behaviour Jarga.Accounts.UseCases.UseCase

  alias Jarga.Repo
  alias Jarga.Accounts.{User, UserToken, Queries}
  alias Jarga.Accounts.Infrastructure.UserTokenRepository

  @doc """
  Executes the update user email use case.

  ## Parameters

  - `params` - Map containing:
    - `:user` - The user whose email to update
    - `:token` - The email change verification token

  - `opts` - Keyword list of options (currently unused)

  ## Returns

  - `{:ok, user}` - Email updated successfully
  - `{:error, :transaction_aborted}` - Operation failed
  """
  @impl true
  def execute(params, _opts \\ []) do
    %{
      user: user,
      token: token
    } = params

    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- UserTokenRepository.get_one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(Queries.tokens_for_user_and_context(user.id, context)) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end
end
