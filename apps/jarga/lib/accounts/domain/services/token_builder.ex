defmodule Jarga.Accounts.Domain.Services.TokenBuilder do
  @moduledoc """
  Domain service for building user authentication tokens.

  This service encapsulates token building logic, delegating cryptographic
  operations to the infrastructure layer (TokenGenerator) while keeping
  the business rules in the domain layer.

  ## Responsibilities

  - Building session tokens with proper timestamps
  - Building hashed email tokens with proper context
  - Defining token structure according to business rules

  ## Infrastructure Delegation

  All cryptographic operations (random generation, hashing, encoding) are
  delegated to TokenGenerator service in the infrastructure layer.
  """

  alias Jarga.Accounts.Infrastructure.Schemas.UserTokenSchema
  alias Jarga.Accounts.Infrastructure.Services.TokenGenerator

  @doc """
  Builds a session token for the given user.

  The session token is stored in the database and used for authentication.
  It includes the user's authenticated_at timestamp.

  ## Parameters

  - `user` - User struct with id and optional authenticated_at
  - `opts` - Keyword list of options
    - `:current_time` - DateTime to use if user has no authenticated_at (default: DateTime.utc_now())

  ## Returns

  `{raw_token, user_token_schema}` tuple where:
  - `raw_token` - Binary token to be stored in session/cookie
  - `user_token_schema` - UserTokenSchema struct to be inserted into database

  ## Examples

      iex> {token, user_token} = TokenBuilder.build_session_token(user)
      iex> is_binary(token)
      true
      iex> user_token.context
      "session"
  """
  def build_session_token(user, opts \\ []) do
    token = TokenGenerator.generate_random_token()
    current_time = Keyword.get(opts, :current_time, DateTime.utc_now(:second))
    dt = user.authenticated_at || current_time

    {token,
     %UserTokenSchema{
       token: token,
       context: "session",
       user_id: user.id,
       authenticated_at: dt
     }}
  end

  @doc """
  Builds a hashed email token for the given user and context.

  The token is hashed and URL-encoded for secure transmission via email.
  The original token is returned for inclusion in the email URL.

  ## Parameters

  - `user` - User struct with id and email
  - `context` - Token context (e.g., "login", "change:old@email.com")

  ## Returns

  `{encoded_token, user_token_schema}` tuple where:
  - `encoded_token` - URL-safe encoded token for email links
  - `user_token_schema` - UserTokenSchema struct with hashed token for database

  ## Examples

      iex> {encoded, user_token} = TokenBuilder.build_email_token(user, "login")
      iex> is_binary(encoded)
      true
      iex> user_token.context
      "login"
      iex> user_token.sent_to
      user.email
  """
  def build_email_token(user, context) do
    build_hashed_token(user, context, user.email)
  end

  # Private helper for building hashed tokens
  defp build_hashed_token(user, context, sent_to) do
    token = TokenGenerator.generate_random_token()
    hashed_token = TokenGenerator.hash_token(token)
    encoded_token = TokenGenerator.encode_token(token)

    {encoded_token,
     %UserTokenSchema{
       token: hashed_token,
       context: context,
       sent_to: sent_to,
       user_id: user.id
     }}
  end
end
