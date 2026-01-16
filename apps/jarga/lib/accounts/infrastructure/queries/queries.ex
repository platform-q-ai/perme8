defmodule Jarga.Accounts.Infrastructure.Queries.Queries do
  @moduledoc """
  Query objects for account-related database queries.

  This module provides composable, reusable query functions following the
  Query Object pattern from the infrastructure layer.

  ## Responsibilities

  - Building Ecto queries for users and tokens
  - Token verification queries (session, magic link, change email)
  - Query composition and filtering

  ## Token Verification

  Token verification queries use `TokenPolicy` for expiry rules, ensuring
  business logic (expiry periods) is defined in the domain layer while
  query building remains in infrastructure.

  ## Usage

      iex> {:ok, query} = Queries.verify_session_token_query(token)
      iex> {user, inserted_at} = Repo.one(query)

  """

  import Ecto.Query, warn: false

  alias Jarga.Accounts.Infrastructure.Schemas.UserTokenSchema
  alias Jarga.Accounts.Infrastructure.Schemas.UserSchema
  alias Jarga.Accounts.Infrastructure.Services.TokenGenerator
  alias Jarga.Accounts.Domain.Policies.TokenPolicy

  @doc """
  Base query for users.
  """
  def base do
    UserSchema
  end

  @doc """
  Base query for user tokens.
  """
  def tokens_base do
    UserTokenSchema
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

  # Token verification queries

  @doc """
  Verifies a session token and returns a query to fetch the user.

  Returns `{:ok, query}` where the query will return `{user, inserted_at}`.
  The user struct includes the `authenticated_at` timestamp from the token.

  The token is valid if it matches the value in the database and has not expired.
  Session tokens are valid for #{TokenPolicy.session_validity_days()} days.

  ## Examples

      iex> {:ok, query} = verify_session_token_query(token)
      iex> {user, inserted_at} = Repo.one(query)

  """
  def verify_session_token_query(token) do
    query =
      from(token in tokens_by_token_and_context(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(^TokenPolicy.session_validity_days(), "day"),
        select: {%{user | authenticated_at: token.authenticated_at}, token.inserted_at}
      )

    {:ok, query}
  end

  @doc """
  Verifies a magic link token and returns a query to fetch the user and token.

  Returns `{:ok, query}` where the query will return `{user, token}`.
  Returns `:error` if the token format is invalid.

  The token must be:
  - Properly encoded and decoded
  - Valid within #{TokenPolicy.magic_link_validity_minutes()} minutes
  - Associated with the current user email (sent_to matches user.email)

  ## Examples

      iex> {:ok, query} = verify_magic_link_token_query(encoded_token)
      iex> {user, token} = Repo.one(query)

      iex> verify_magic_link_token_query("invalid")
      :error

  """
  def verify_magic_link_token_query(token) do
    case TokenGenerator.decode_token(token) do
      {:ok, decoded_token} when byte_size(decoded_token) == 32 ->
        hashed_token = TokenGenerator.hash_token(decoded_token)

        query =
          from(token in tokens_by_token_and_context(hashed_token, "login"),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(^TokenPolicy.magic_link_validity_minutes(), "minute"),
            where: token.sent_to == user.email,
            select: {user, token}
          )

        {:ok, query}

      _ ->
        :error
    end
  end

  @doc """
  Verifies a change email token and returns a query to fetch the token.

  Returns `{:ok, query}` where the query will return the `UserToken`.
  Returns `:error` if the token format is invalid.

  The token must be:
  - Properly encoded and decoded
  - Valid within #{TokenPolicy.change_email_validity_days()} days
  - Have a context starting with "change:"

  ## Examples

      iex> {:ok, query} = verify_change_email_token_query(encoded_token, "change:new@example.com")
      iex> token = Repo.one(query)

      iex> verify_change_email_token_query("invalid", "change:new@example.com")
      :error

  """
  def verify_change_email_token_query(token, "change:" <> _ = context) do
    case TokenGenerator.decode_token(token) do
      {:ok, decoded_token} when byte_size(decoded_token) == 32 ->
        hashed_token = TokenGenerator.hash_token(decoded_token)

        query =
          from(token in tokens_by_token_and_context(hashed_token, context),
            where: token.inserted_at > ago(^TokenPolicy.change_email_validity_days(), "day")
          )

        {:ok, query}

      _ ->
        :error
    end
  end
end
