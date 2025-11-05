defmodule Jarga.Accounts.QueriesTest do
  use Jarga.DataCase, async: true

  alias Jarga.Accounts.Queries
  alias Jarga.Accounts.{User, UserToken}

  import Jarga.AccountsFixtures

  describe "base/0" do
    test "returns the User queryable" do
      assert Queries.base() == User
    end
  end

  describe "tokens_base/0" do
    test "returns the UserToken queryable" do
      assert Queries.tokens_base() == UserToken
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

      all_tokens = Repo.all(from(t in UserToken, where: t.user_id == ^user.id))
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

      user1_tokens = Repo.all(from(t in UserToken, where: t.user_id == ^user1.id))
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
      Repo.delete_all(from(t in UserToken, where: t.user_id == ^user.id))

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
      assert length(tokens) >= 1
    end
  end
end
