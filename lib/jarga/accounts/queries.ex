defmodule Jarga.Accounts.Queries do
  @moduledoc """
  Query objects for account-related database queries.

  This module provides composable, reusable query functions following the
  Query Object pattern from the infrastructure layer.
  """

  import Ecto.Query, warn: false

  alias Jarga.Accounts.{User, UserToken}

  @doc """
  Base query for users.
  """
  def base do
    User
  end

  @doc """
  Base query for user tokens.
  """
  def tokens_base do
    UserToken
  end

  @doc """
  Filters users by email (case-insensitive).

  Returns a query that finds a user by email using case-insensitive comparison.

  ## Examples

      iex> by_email_case_insensitive("Foo@Example.COM") |> Repo.one()
      %User{email: "foo@example.com"}

  """
  def by_email_case_insensitive(email) when is_binary(email) do
    downcased_email = String.downcase(email)

    from(u in base(),
      where: fragment("LOWER(?)", u.email) == ^downcased_email
    )
  end

  @doc """
  Filters tokens by user_id and context.

  Returns a query that finds all tokens for a specific user and context.

  ## Examples

      iex> tokens_for_user_and_context(user_id, "session") |> Repo.all()
      [%UserToken{}, ...]

  """
  def tokens_for_user_and_context(user_id, context) do
    from(t in tokens_base(),
      where: t.user_id == ^user_id and t.context == ^context
    )
  end

  @doc """
  Filters tokens by token value and context.

  Returns a query that finds tokens by their token value and context.

  ## Examples

      iex> tokens_by_token_and_context(token, "session") |> Repo.all()
      [%UserToken{}, ...]

  """
  def tokens_by_token_and_context(token, context) do
    from(t in tokens_base(),
      where: t.token == ^token and t.context == ^context
    )
  end

  @doc """
  Filters tokens by a list of token IDs.

  Returns a query that finds all tokens whose IDs are in the provided list.

  ## Examples

      iex> tokens_by_ids([1, 2, 3]) |> Repo.all()
      [%UserToken{}, ...]

  """
  def tokens_by_ids(token_ids) when is_list(token_ids) do
    from(t in tokens_base(),
      where: t.id in ^token_ids
    )
  end

  @doc """
  Filters tokens by user_id.

  Returns a query that finds all tokens for a specific user.

  ## Examples

      iex> tokens_for_user(user_id) |> Repo.all()
      [%UserToken{}, ...]

  """
  def tokens_for_user(user_id) do
    from(t in tokens_base(),
      where: t.user_id == ^user_id
    )
  end
end
