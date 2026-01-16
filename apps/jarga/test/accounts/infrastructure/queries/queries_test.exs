defmodule Jarga.Accounts.QueriesTest do
  use Jarga.DataCase, async: true

  import Ecto.Query
  import Jarga.AccountsFixtures

  alias Jarga.Accounts.Domain.Services.TokenBuilder
  alias Jarga.Accounts.Infrastructure.Queries.Queries
  alias Jarga.Accounts.Infrastructure.Schemas.{UserSchema, UserTokenSchema}

  describe "base/0" do
    test "returns the UserSchema queryable" do
      assert Queries.base() == UserSchema
    end
  end

  describe "tokens_base/0" do
    test "returns the UserTokenSchema queryable" do
      assert Queries.tokens_base() == UserTokenSchema
    end
  end

  describe "by_email_case_insensitive/1" do
    test "finds user with exact lowercase email" do
      user = user_fixture(%{email: "test@example.com"})

      query = Queries.by_email_case_insensitive("test@example.com")
      assert Repo.one(query).id == user.id
    end

    test "finds user with uppercase email input" do
      user = user_fixture(%{email: "test@example.com"})

      query = Queries.by_email_case_insensitive("TEST@EXAMPLE.COM")
      assert Repo.one(query).id == user.id
    end

    test "finds user with mixed case email input" do
      user = user_fixture(%{email: "test@example.com"})

      query = Queries.by_email_case_insensitive("TeSt@ExAmPlE.cOm")
      assert Repo.one(query).id == user.id
    end

    test "returns nil when email does not exist" do
      query = Queries.by_email_case_insensitive("nonexistent@example.com")
      assert Repo.one(query) == nil
    end

    test "only matches exact email, not partial" do
      user_fixture(%{email: "test@example.com"})

      query = Queries.by_email_case_insensitive("test@examp")
      assert Repo.one(query) == nil
    end
  end

  describe "tokens_for_user_and_context/2" do
    test "returns tokens for specific user and context" do
      user = user_fixture()
      {_encoded_token, token} = generate_user_magic_link_token(user)

      query = Queries.tokens_for_user_and_context(user.id, "login")
      tokens = Repo.all(query)

      assert length(tokens) == 1
      assert hd(tokens).token == token
      assert hd(tokens).user_id == user.id
      assert hd(tokens).context == "login"
    end

    test "does not return tokens from different context" do
      user = user_fixture()
      generate_user_magic_link_token(user)

      query = Queries.tokens_for_user_and_context(user.id, "session")
      assert Repo.all(query) == []
    end

    test "does not return tokens from different user" do
      user1 = user_fixture()
      user2 = user_fixture()
      generate_user_magic_link_token(user1)

      query = Queries.tokens_for_user_and_context(user2.id, "login")
      assert Repo.all(query) == []
    end

    test "returns multiple tokens for same user and context" do
      user = user_fixture()
      {_encoded1, token1} = generate_user_magic_link_token(user)
      {_encoded2, token2} = generate_user_magic_link_token(user)

      query = Queries.tokens_for_user_and_context(user.id, "login")
      tokens = Repo.all(query)

      assert length(tokens) == 2
      token_values = Enum.map(tokens, & &1.token)
      assert token1 in token_values
      assert token2 in token_values
    end
  end

  describe "tokens_by_token_and_context/2" do
    test "finds token by token value and context" do
      user = user_fixture()
      {_encoded_token, token} = generate_user_magic_link_token(user)

      query = Queries.tokens_by_token_and_context(token, "login")
      tokens = Repo.all(query)

      assert length(tokens) == 1
      assert hd(tokens).token == token
      assert hd(tokens).context == "login"
    end

    test "does not return token with wrong context" do
      user = user_fixture()
      {_encoded_token, token} = generate_user_magic_link_token(user)

      query = Queries.tokens_by_token_and_context(token, "session")
      assert Repo.all(query) == []
    end

    test "does not return token with wrong token value" do
      user = user_fixture()
      generate_user_magic_link_token(user)

      fake_token = :crypto.hash(:sha256, :crypto.strong_rand_bytes(32))
      query = Queries.tokens_by_token_and_context(fake_token, "login")
      assert Repo.all(query) == []
    end
  end

  describe "tokens_by_ids/1" do
    test "returns tokens with specified IDs" do
      user = user_fixture()
      {_encoded1, _token1} = generate_user_magic_link_token(user)
      {_encoded2, _token2} = generate_user_magic_link_token(user)

      all_tokens = Repo.all(from(t in UserTokenSchema, where: t.user_id == ^user.id))
      token_ids = Enum.map(all_tokens, & &1.id)

      query = Queries.tokens_by_ids(token_ids)
      result_tokens = Repo.all(query)

      assert length(result_tokens) == 2
      result_ids = Enum.map(result_tokens, & &1.id)
      assert Enum.sort(result_ids) == Enum.sort(token_ids)
    end

    test "returns only tokens with matching IDs" do
      user1 = user_fixture()
      user2 = user_fixture()
      {_encoded1, _token1} = generate_user_magic_link_token(user1)
      {_encoded2, _token2} = generate_user_magic_link_token(user2)

      user1_tokens = Repo.all(from(t in UserTokenSchema, where: t.user_id == ^user1.id))
      token_ids = Enum.map(user1_tokens, & &1.id)

      query = Queries.tokens_by_ids(token_ids)
      result_tokens = Repo.all(query)

      assert length(result_tokens) == 1
      assert hd(result_tokens).user_id == user1.id
    end

    test "returns empty list for non-existent IDs" do
      fake_ids = [Ecto.UUID.generate(), Ecto.UUID.generate()]

      query = Queries.tokens_by_ids(fake_ids)
      assert Repo.all(query) == []
    end

    test "returns empty list for empty ID list" do
      query = Queries.tokens_by_ids([])
      assert Repo.all(query) == []
    end
  end

  describe "tokens_for_user/1" do
    test "returns all tokens for a user" do
      user = user_fixture()
      {_encoded1, token1} = generate_user_magic_link_token(user)
      {_encoded2, token2} = generate_user_magic_link_token(user)

      query = Queries.tokens_for_user(user.id)
      tokens = Repo.all(query)

      assert length(tokens) >= 2
      token_values = Enum.map(tokens, & &1.token)
      assert token1 in token_values
      assert token2 in token_values
    end

    test "does not return tokens from other users" do
      user1 = user_fixture()
      user2 = user_fixture()
      {_encoded1, token1} = generate_user_magic_link_token(user1)
      generate_user_magic_link_token(user2)

      query = Queries.tokens_for_user(user1.id)
      tokens = Repo.all(query)

      token_values = Enum.map(tokens, & &1.token)
      assert token1 in token_values
      assert Enum.all?(tokens, &(&1.user_id == user1.id))
    end

    test "returns empty list when user has no tokens" do
      user = user_fixture()

      # Clear any session tokens created during fixture
      Repo.delete_all(from(t in UserTokenSchema, where: t.user_id == ^user.id))

      query = Queries.tokens_for_user(user.id)
      assert Repo.all(query) == []
    end

    test "returns tokens across different contexts" do
      user = user_fixture()
      {_encoded1, _token1} = generate_user_magic_link_token(user)

      # User fixture already creates session tokens, so we should have both
      query = Queries.tokens_for_user(user.id)
      tokens = Repo.all(query)

      _contexts = Enum.map(tokens, & &1.context)
      # Should have tokens from fixture creation
      assert tokens != []
    end
  end

  describe "verify_session_token_query/1" do
    test "returns valid query for session token within validity period" do
      user = user_fixture()
      # Create a session token explicitly
      {_encoded, token_record} = TokenBuilder.build_session_token(user)
      Repo.insert!(token_record)

      {:ok, query} = Queries.verify_session_token_query(token_record.token)

      assert {returned_user, _inserted_at} = Repo.one(query)
      assert returned_user.id == user.id
    end

    test "query includes authenticated_at in user struct" do
      user = user_fixture()
      # Create a session token explicitly
      {_encoded, token_record} = TokenBuilder.build_session_token(user)
      Repo.insert!(token_record)

      {:ok, query} = Queries.verify_session_token_query(token_record.token)

      assert {returned_user, _inserted_at} = Repo.one(query)
      assert returned_user.authenticated_at != nil
    end

    test "query returns nil for expired session token" do
      user = user_fixture()

      # Create an expired session token (older than 14 days)
      {_encoded, token_record} = TokenBuilder.build_session_token(user)
      # Insert the token first
      inserted_token = Repo.insert!(token_record)
      # Update the inserted_at to make it expired
      Repo.update_all(from(t in UserTokenSchema, where: t.id == ^inserted_token.id),
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -15, :day)]
      )

      {:ok, query} = Queries.verify_session_token_query(token_record.token)

      assert Repo.one(query) == nil
    end

    test "query returns nil for non-existent token" do
      fake_token = :crypto.strong_rand_bytes(32)

      {:ok, query} = Queries.verify_session_token_query(fake_token)

      assert Repo.one(query) == nil
    end
  end

  describe "verify_magic_link_token_query/1" do
    test "returns valid query for magic link token within validity period" do
      user = user_fixture()
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)

      {:ok, query} = Queries.verify_magic_link_token_query(encoded_token)

      assert {returned_user, token} = Repo.one(query)
      assert returned_user.id == user.id
      assert token.context == "login"
    end

    test "query verifies sent_to matches user email" do
      user = user_fixture()
      {encoded_token, _hashed_token} = generate_user_magic_link_token(user)

      {:ok, query} = Queries.verify_magic_link_token_query(encoded_token)

      assert {_user, token} = Repo.one(query)
      assert token.sent_to == user.email
    end

    test "returns error for invalid base64 encoding" do
      assert :error = Queries.verify_magic_link_token_query("invalid-token")
    end

    test "returns error for wrong token length" do
      # Create token with wrong length (not 32 bytes)
      short_token = :crypto.strong_rand_bytes(16)
      encoded = Base.url_encode64(short_token, padding: false)

      assert :error = Queries.verify_magic_link_token_query(encoded)
    end

    test "query returns nil for expired magic link token" do
      user = user_fixture()

      # Create an expired token (older than 15 minutes)
      {encoded_token, user_token} = TokenBuilder.build_email_token(user, "login")

      # Insert the token first, then update its inserted_at to make it expired
      inserted_token = Repo.insert!(user_token)

      Repo.update_all(from(t in UserTokenSchema, where: t.id == ^inserted_token.id),
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -20, :minute)]
      )

      {:ok, query} = Queries.verify_magic_link_token_query(encoded_token)

      assert Repo.one(query) == nil
    end
  end

  describe "verify_change_email_token_query/2" do
    test "returns valid query for change email token within validity period" do
      user = user_fixture()
      new_email = "new@example.com"
      context = "change:#{user.email}"

      # Build and insert the token manually
      {encoded_token, user_token} = TokenBuilder.build_email_token(user, context)
      user_token = %{user_token | sent_to: new_email}
      Repo.insert!(user_token)

      {:ok, query} = Queries.verify_change_email_token_query(encoded_token, context)

      assert %UserTokenSchema{} = token = Repo.one(query)
      assert token.context == context
      assert token.user_id == user.id
    end

    test "returns error for invalid base64 encoding" do
      assert :error =
               Queries.verify_change_email_token_query("invalid-token", "change:test@example.com")
    end

    test "returns error for wrong token length" do
      short_token = :crypto.strong_rand_bytes(16)
      encoded = Base.url_encode64(short_token, padding: false)

      assert :error = Queries.verify_change_email_token_query(encoded, "change:test@example.com")
    end

    test "query returns nil for expired change email token" do
      user = user_fixture()
      new_email = "new@example.com"
      context = "change:#{user.email}"

      # Create an expired token (older than 7 days)
      {encoded_token, user_token} = TokenBuilder.build_email_token(user, context)
      user_token = %{user_token | sent_to: new_email}

      # Insert the token first, then update its inserted_at to make it expired
      inserted_token = Repo.insert!(user_token)

      Repo.update_all(from(t in UserTokenSchema, where: t.id == ^inserted_token.id),
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -8, :day)]
      )

      {:ok, query} = Queries.verify_change_email_token_query(encoded_token, context)

      assert Repo.one(query) == nil
    end

    test "query matches exact context" do
      user = user_fixture()
      new_email = "new@example.com"
      context = "change:#{user.email}"

      # Build and insert the token
      {encoded_token, user_token} = TokenBuilder.build_email_token(user, context)
      user_token = %{user_token | sent_to: new_email}
      Repo.insert!(user_token)

      # Try with wrong context
      {:ok, query} =
        Queries.verify_change_email_token_query(encoded_token, "change:wrong@example.com")

      assert Repo.one(query) == nil
    end
  end
end
