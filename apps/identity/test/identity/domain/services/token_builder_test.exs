defmodule Identity.Domain.Services.TokenBuilderTest do
  @moduledoc """
  Unit tests for the TokenBuilder domain service.

  These tests use mock implementations of the infrastructure dependencies
  to verify the business logic without database access.
  """

  use ExUnit.Case, async: true

  alias Identity.Domain.Services.TokenBuilder

  # Mock token generator for testing
  defmodule MockTokenGenerator do
    @doc "Returns a predictable token for testing"
    def generate_random_token, do: "mock_random_token_bytes"

    @doc "Returns a predictable hash for testing"
    def hash_token(token), do: "hashed_#{token}"

    @doc "Returns a predictable encoding for testing"
    def encode_token(token), do: "encoded_#{token}"
  end

  # Mock user token schema for testing
  defmodule MockUserTokenSchema do
    defstruct [:token, :context, :user_id, :authenticated_at, :sent_to]
  end

  describe "build_session_token/2" do
    test "builds a session token with user's authenticated_at timestamp" do
      now = ~U[2024-01-15 12:00:00Z]

      user = %{
        id: "user-123",
        authenticated_at: now
      }

      {raw_token, user_token} =
        TokenBuilder.build_session_token(user,
          token_generator: MockTokenGenerator,
          user_token_schema: MockUserTokenSchema
        )

      assert raw_token == "mock_random_token_bytes"
      assert %MockUserTokenSchema{} = user_token
      assert user_token.token == "mock_random_token_bytes"
      assert user_token.context == "session"
      assert user_token.user_id == "user-123"
      assert user_token.authenticated_at == now
    end

    test "uses current_time when user has no authenticated_at" do
      now = ~U[2024-01-15 12:00:00Z]

      user = %{
        id: "user-456",
        authenticated_at: nil
      }

      {_raw_token, user_token} =
        TokenBuilder.build_session_token(user,
          token_generator: MockTokenGenerator,
          user_token_schema: MockUserTokenSchema,
          current_time: now
        )

      assert user_token.authenticated_at == now
    end

    test "returns tuple with raw token and token struct" do
      user = %{id: "user-789", authenticated_at: DateTime.utc_now()}

      result =
        TokenBuilder.build_session_token(user,
          token_generator: MockTokenGenerator,
          user_token_schema: MockUserTokenSchema
        )

      assert {raw_token, user_token} = result
      assert is_binary(raw_token)
      assert is_struct(user_token)
    end
  end

  describe "build_email_token/3" do
    test "builds a hashed email token for login context" do
      user = %{
        id: "user-123",
        email: "user@example.com"
      }

      {encoded_token, user_token} =
        TokenBuilder.build_email_token(user, "login",
          token_generator: MockTokenGenerator,
          user_token_schema: MockUserTokenSchema
        )

      assert encoded_token == "encoded_mock_random_token_bytes"
      assert %MockUserTokenSchema{} = user_token
      assert user_token.token == "hashed_mock_random_token_bytes"
      assert user_token.context == "login"
      assert user_token.user_id == "user-123"
      assert user_token.sent_to == "user@example.com"
    end

    test "builds a hashed email token for change email context" do
      user = %{
        id: "user-456",
        email: "new@example.com"
      }

      {encoded_token, user_token} =
        TokenBuilder.build_email_token(
          user,
          "change:old@example.com",
          token_generator: MockTokenGenerator,
          user_token_schema: MockUserTokenSchema
        )

      assert encoded_token == "encoded_mock_random_token_bytes"
      assert user_token.context == "change:old@example.com"
      assert user_token.sent_to == "new@example.com"
    end

    test "returns encoded token for URL-safe email links" do
      user = %{id: "user-789", email: "test@example.com"}

      {encoded_token, _user_token} =
        TokenBuilder.build_email_token(user, "login",
          token_generator: MockTokenGenerator,
          user_token_schema: MockUserTokenSchema
        )

      # The encoded token should be the URL-safe version
      assert String.starts_with?(encoded_token, "encoded_")
    end

    test "stores hashed token in the struct for database" do
      user = %{id: "user-abc", email: "test@example.com"}

      {_encoded_token, user_token} =
        TokenBuilder.build_email_token(user, "login",
          token_generator: MockTokenGenerator,
          user_token_schema: MockUserTokenSchema
        )

      # The stored token should be the hashed version
      assert String.starts_with?(user_token.token, "hashed_")
    end
  end

  describe "integration with real token generator" do
    test "build_session_token works with real infrastructure" do
      user = %{
        id: "real-user-123",
        authenticated_at: DateTime.utc_now()
      }

      {raw_token, user_token} = TokenBuilder.build_session_token(user)

      # Raw token should be binary
      assert is_binary(raw_token)
      assert byte_size(raw_token) == 32

      # User token should be an actual schema struct
      assert user_token.token == raw_token
      assert user_token.context == "session"
      assert user_token.user_id == "real-user-123"
    end

    test "build_email_token works with real infrastructure" do
      user = %{
        id: "real-user-456",
        email: "real@example.com"
      }

      {encoded_token, user_token} = TokenBuilder.build_email_token(user, "login")

      # Encoded token should be URL-safe base64
      assert is_binary(encoded_token)
      assert String.match?(encoded_token, ~r/^[A-Za-z0-9_-]+$/)

      # Stored token should be a hash (not the raw token)
      assert is_binary(user_token.token)
      assert user_token.context == "login"
      assert user_token.sent_to == "real@example.com"
    end
  end
end
