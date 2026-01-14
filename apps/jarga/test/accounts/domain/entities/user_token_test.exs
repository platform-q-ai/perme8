defmodule Jarga.Accounts.UserTokenTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures

  alias Jarga.Accounts.Domain.Services.TokenBuilder
  alias Jarga.Accounts.Infrastructure.Queries.Queries
  alias Jarga.Accounts.Infrastructure.Schemas.UserSchema

  describe "build_session_token/1" do
    test "generates a session token" do
      user = user_fixture()

      {token, user_token} = TokenBuilder.build_session_token(user)

      assert is_binary(token)
      assert byte_size(token) == 32
      assert user_token.token == token
      assert user_token.context == "session"
      assert user_token.user_id == user.id
    end

    test "uses user's authenticated_at when present" do
      user = user_fixture()
      authenticated_at = DateTime.utc_now(:second) |> DateTime.add(-3600, :second)
      user_with_auth = %{user | authenticated_at: authenticated_at}

      {_token, user_token} = TokenBuilder.build_session_token(user_with_auth)

      assert user_token.authenticated_at == authenticated_at
    end

    test "uses current time when user has no authenticated_at" do
      user = %{user_fixture() | authenticated_at: nil}

      {_token, user_token} = TokenBuilder.build_session_token(user)

      assert user_token.authenticated_at != nil
      assert DateTime.diff(DateTime.utc_now(), user_token.authenticated_at) < 5
    end

    test "generates unique tokens" do
      user = user_fixture()

      {token1, _} = TokenBuilder.build_session_token(user)
      {token2, _} = TokenBuilder.build_session_token(user)

      assert token1 != token2
    end
  end

  describe "verify_session_token_query/1" do
    test "returns valid query for valid session token" do
      user = user_fixture()
      {token, user_token} = TokenBuilder.build_session_token(user)
      Repo.insert!(user_token)

      {:ok, query} = Queries.verify_session_token_query(token)
      result = Repo.one(query)

      assert result != nil
      {returned_user, _inserted_at} = result
      assert returned_user.id == user.id
    end

    test "returns user with authenticated_at from token" do
      user = user_fixture()
      authenticated_at = DateTime.utc_now(:second) |> DateTime.add(-1800, :second)
      user_with_auth = %{user | authenticated_at: authenticated_at}

      {token, user_token} = TokenBuilder.build_session_token(user_with_auth)
      Repo.insert!(user_token)

      {:ok, query} = Queries.verify_session_token_query(token)
      {returned_user, _inserted_at} = Repo.one(query)

      assert returned_user.authenticated_at == authenticated_at
    end

    test "does not return expired session token" do
      user = user_fixture()
      {token, user_token} = TokenBuilder.build_session_token(user)
      Repo.insert!(user_token)

      # Set token to 15 days ago (past 14 day expiry)
      offset_user_token(user_token.token, -15, :day)

      {:ok, query} = Queries.verify_session_token_query(token)
      assert Repo.one(query) == nil
    end

    test "does not return token with wrong context" do
      user = user_fixture()
      {_encoded_token, raw_token} = generate_user_magic_link_token(user)

      # Try to verify as session token (but it's a login token)
      {:ok, query} = Queries.verify_session_token_query(raw_token)
      assert Repo.one(query) == nil
    end

    test "returns inserted_at timestamp" do
      user = user_fixture()
      {token, user_token} = TokenBuilder.build_session_token(user)
      Repo.insert!(user_token)

      {:ok, query} = Queries.verify_session_token_query(token)
      {_user, inserted_at} = Repo.one(query)

      assert inserted_at != nil
      assert DateTime.diff(DateTime.utc_now(), inserted_at) < 5
    end
  end

  describe "build_email_token/2" do
    test "generates a login token" do
      user = user_fixture(%{email: "test@example.com"})

      {encoded_token, user_token} = TokenBuilder.build_email_token(user, "login")

      assert is_binary(encoded_token)
      assert String.length(encoded_token) > 0
      assert user_token.context == "login"
      assert user_token.sent_to == "test@example.com"
      assert user_token.user_id == user.id
      assert is_binary(user_token.token)
    end

    test "generates change email token" do
      user = user_fixture(%{email: "original@example.com"})

      {encoded_token, user_token} = TokenBuilder.build_email_token(user, "change:new@example.com")

      assert is_binary(encoded_token)
      assert user_token.context == "change:new@example.com"
      assert user_token.sent_to == "original@example.com"
      assert user_token.user_id == user.id
    end

    test "hashes the token for storage" do
      user = user_fixture()

      {encoded_token, user_token} = TokenBuilder.build_email_token(user, "login")

      # Token in database should be hashed
      assert user_token.token != encoded_token
      assert byte_size(user_token.token) == 32
    end

    test "generates unique tokens" do
      user = user_fixture()

      {token1, _} = TokenBuilder.build_email_token(user, "login")
      {token2, _} = TokenBuilder.build_email_token(user, "login")

      assert token1 != token2
    end

    test "encoded token is URL-safe" do
      user = user_fixture()

      {encoded_token, _} = TokenBuilder.build_email_token(user, "login")

      # Should not contain padding characters
      refute String.contains?(encoded_token, "=")
      # Should be URL-safe base64
      assert String.match?(encoded_token, ~r/^[A-Za-z0-9_-]+$/)
    end
  end

  describe "verify_magic_link_token_query/1" do
    test "returns valid query for valid magic link token" do
      user = user_fixture()
      {encoded_token, user_token} = TokenBuilder.build_email_token(user, "login")
      Repo.insert!(user_token)

      {:ok, query} = Queries.verify_magic_link_token_query(encoded_token)
      result = Repo.one(query)

      assert result != nil
      {returned_user, _token} = result
      assert returned_user.id == user.id
    end

    test "does not return expired magic link token" do
      user = user_fixture()
      {encoded_token, user_token} = TokenBuilder.build_email_token(user, "login")
      Repo.insert!(user_token)

      # Set token to 20 minutes ago (past 15 minute expiry)
      offset_user_token(user_token.token, -20, :minute)

      {:ok, query} = Queries.verify_magic_link_token_query(encoded_token)
      assert Repo.one(query) == nil
    end

    test "does not return token if email changed" do
      user = user_fixture(%{email: "original@example.com"})
      {encoded_token, user_token} = TokenBuilder.build_email_token(user, "login")
      Repo.insert!(user_token)

      # Change user's email
      Repo.update!(Ecto.Changeset.change(UserSchema.to_schema(user), email: "new@example.com"))

      {:ok, query} = Queries.verify_magic_link_token_query(encoded_token)
      assert Repo.one(query) == nil
    end

    test "returns error for invalid token encoding" do
      assert Queries.verify_magic_link_token_query("invalid-token") == :error
      assert Queries.verify_magic_link_token_query("") == :error
    end

    test "does not return token with wrong context" do
      user = user_fixture()
      {encoded_token, user_token} = TokenBuilder.build_email_token(user, "change:new@example.com")
      Repo.insert!(user_token)

      # Try to verify as magic link (but it's a change email token)
      {:ok, query} = Queries.verify_magic_link_token_query(encoded_token)
      assert Repo.one(query) == nil
    end

    test "returns both user and token" do
      user = user_fixture()
      {encoded_token, user_token} = TokenBuilder.build_email_token(user, "login")
      user_token = Repo.insert!(user_token)

      {:ok, query} = Queries.verify_magic_link_token_query(encoded_token)
      {returned_user, returned_token} = Repo.one(query)

      assert returned_user.id == user.id
      assert returned_token.id == user_token.id
    end
  end

  describe "verify_change_email_token_query/2" do
    test "returns valid query for valid change email token" do
      user = user_fixture()
      context = "change:new@example.com"
      {encoded_token, user_token} = TokenBuilder.build_email_token(user, context)
      user_token = Repo.insert!(user_token)

      {:ok, query} = Queries.verify_change_email_token_query(encoded_token, context)
      result = Repo.one(query)

      assert result != nil
      assert result.id == user_token.id
    end

    test "does not return expired change email token" do
      user = user_fixture()
      context = "change:new@example.com"
      {encoded_token, user_token} = TokenBuilder.build_email_token(user, context)
      Repo.insert!(user_token)

      # Set token to 8 days ago (past 7 day expiry)
      offset_user_token(user_token.token, -8, :day)

      {:ok, query} = Queries.verify_change_email_token_query(encoded_token, context)
      assert Repo.one(query) == nil
    end

    test "does not return token with wrong context" do
      user = user_fixture()

      {encoded_token, user_token} =
        TokenBuilder.build_email_token(user, "change:email1@example.com")

      Repo.insert!(user_token)

      # Try to verify with different context
      {:ok, query} =
        Queries.verify_change_email_token_query(encoded_token, "change:email2@example.com")

      assert Repo.one(query) == nil
    end

    test "returns error for invalid token encoding" do
      assert Queries.verify_change_email_token_query("invalid", "change:new@example.com") ==
               :error
    end

    test "requires context to start with change:" do
      user = user_fixture()
      {encoded_token, user_token} = TokenBuilder.build_email_token(user, "change:new@example.com")
      Repo.insert!(user_token)

      # Should not match the function clause for non-change: contexts
      assert_raise FunctionClauseError, fn ->
        Queries.verify_change_email_token_query(encoded_token, "login")
      end
    end

    test "returns token within validity period" do
      user = user_fixture()
      context = "change:new@example.com"
      {encoded_token, user_token} = TokenBuilder.build_email_token(user, context)
      Repo.insert!(user_token)

      # Set token to 3 days ago (within 7 day expiry)
      offset_user_token(user_token.token, -3, :day)

      {:ok, query} = Queries.verify_change_email_token_query(encoded_token, context)
      assert Repo.one(query) != nil
    end
  end
end
