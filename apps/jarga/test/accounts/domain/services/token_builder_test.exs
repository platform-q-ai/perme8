defmodule Jarga.Accounts.Domain.Services.TokenBuilderTest do
  use ExUnit.Case, async: true

  alias Jarga.Accounts.Domain.Services.TokenBuilder
  alias Jarga.Accounts.Infrastructure.Schemas.UserTokenSchema

  describe "build_session_token/1" do
    test "generates a session token with user id" do
      user = %{id: "user123", authenticated_at: nil}

      {token, user_token} = TokenBuilder.build_session_token(user)

      assert is_binary(token)
      assert byte_size(token) == 32
      assert %UserTokenSchema{} = user_token
      assert user_token.user_id == "user123"
      assert user_token.context == "session"
      assert user_token.token == token
    end

    test "uses user's authenticated_at when present" do
      authenticated_at = DateTime.utc_now(:second)
      user = %{id: "user123", authenticated_at: authenticated_at}

      {_token, user_token} = TokenBuilder.build_session_token(user)

      assert user_token.authenticated_at == authenticated_at
    end

    test "uses current time when user has no authenticated_at" do
      user = %{id: "user123", authenticated_at: nil}

      {_token, user_token} = TokenBuilder.build_session_token(user)

      assert user_token.authenticated_at != nil
      assert DateTime.diff(DateTime.utc_now(:second), user_token.authenticated_at, :second) <= 1
    end

    test "generates unique tokens" do
      user = %{id: "user123", authenticated_at: nil}

      {token1, _} = TokenBuilder.build_session_token(user)
      {token2, _} = TokenBuilder.build_session_token(user)

      assert token1 != token2
    end
  end

  describe "build_email_token/2" do
    test "generates an email token with proper context" do
      user = %{id: "user123", email: "user@example.com"}

      {encoded_token, user_token} = TokenBuilder.build_email_token(user, "login")

      assert is_binary(encoded_token)
      assert String.valid?(encoded_token)
      assert %UserTokenSchema{} = user_token
      assert user_token.user_id == "user123"
      assert user_token.context == "login"
      assert user_token.sent_to == "user@example.com"
    end

    test "hashes the token before storing" do
      user = %{id: "user123", email: "user@example.com"}

      {encoded_token, user_token} = TokenBuilder.build_email_token(user, "login")

      # The stored token should be hashed (different from encoded)
      assert user_token.token != encoded_token
      assert is_binary(user_token.token)
      assert byte_size(user_token.token) == 32
    end

    test "encodes token for URL-safe transmission" do
      user = %{id: "user123", email: "user@example.com"}

      {encoded_token, _user_token} = TokenBuilder.build_email_token(user, "login")

      # Should not contain characters that need URL encoding
      refute String.contains?(encoded_token, "+")
      refute String.contains?(encoded_token, "/")
      refute String.contains?(encoded_token, "=")
    end

    test "generates unique tokens" do
      user = %{id: "user123", email: "user@example.com"}

      {token1, _} = TokenBuilder.build_email_token(user, "login")
      {token2, _} = TokenBuilder.build_email_token(user, "login")

      assert token1 != token2
    end

    test "supports change email context" do
      user = %{id: "user123", email: "old@example.com"}

      {_encoded_token, user_token} =
        TokenBuilder.build_email_token(user, "change:old@example.com")

      assert user_token.context == "change:old@example.com"
      assert user_token.sent_to == "old@example.com"
    end
  end
end
