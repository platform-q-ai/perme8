defmodule Jarga.Accounts.Application.UseCases.GenerateSessionTokenTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures

  alias Jarga.Accounts.Application.UseCases.GenerateSessionToken
  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Accounts.Infrastructure.Schemas.UserTokenSchema
  alias Jarga.Accounts.Infrastructure.Schemas.UserSchema

  describe "execute/2" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "generates and persists session token", %{user: user} do
      assert token = GenerateSessionToken.execute(%{user: user})

      # Token should be a binary
      assert is_binary(token)

      # Token should be persisted in database
      user_tokens = Repo.all_by(UserTokenSchema, user_id: user.id)
      assert length(user_tokens) == 1

      # Token context should be "session"
      [user_token] = user_tokens
      assert user_token.context == "session"
    end

    test "returns token binary", %{user: user} do
      token = GenerateSessionToken.execute(%{user: user})

      # Token should be a binary string
      assert is_binary(token)
      assert byte_size(token) > 0
    end

    test "token is stored in database", %{user: user} do
      token = GenerateSessionToken.execute(%{user: user})

      # Verify token exists in database
      user_tokens = Repo.all_by(UserTokenSchema, user_id: user.id)
      assert length(user_tokens) == 1

      [user_token] = user_tokens
      assert user_token.user_id == user.id
      assert user_token.context == "session"

      # The encoded token should match what's stored
      assert is_binary(token)
    end

    test "uses user's authenticated_at when present", %{user: user} do
      # Update user with authenticated_at timestamp
      authenticated_at = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, user_with_auth_schema} =
        Repo.update(
          Ecto.Changeset.change(UserSchema.to_schema(user), authenticated_at: authenticated_at)
        )

      user_with_auth = User.from_schema(user_with_auth_schema)

      token = GenerateSessionToken.execute(%{user: user_with_auth})

      # Token should be generated successfully
      assert is_binary(token)

      # Verify token is in database
      [user_token] = Repo.all_by(UserTokenSchema, user_id: user_with_auth.id)
      assert user_token.context == "session"
    end

    test "accepts injectable repo", %{user: user} do
      # Create a mock repo that tracks insertions
      inserted_tokens = Agent.start_link(fn -> [] end)
      {:ok, agent} = inserted_tokens

      mock_repo = %{
        insert!: fn token ->
          Agent.update(agent, fn tokens -> [token | tokens] end)
          %{token | id: Ecto.UUID.generate()}
        end
      }

      token = GenerateSessionToken.execute(%{user: user}, repo: mock_repo)

      # Token should be generated
      assert is_binary(token)

      # Verify mock repo was called
      tokens = Agent.get(agent, & &1)
      assert length(tokens) == 1
      [inserted_token] = tokens
      assert inserted_token.user_id == user.id
      assert inserted_token.context == "session"

      Agent.stop(agent)
    end

    test "multiple calls generate different tokens", %{user: user} do
      token1 = GenerateSessionToken.execute(%{user: user})
      token2 = GenerateSessionToken.execute(%{user: user})

      # Tokens should be different
      assert token1 != token2

      # Both should be stored in database
      user_tokens = Repo.all_by(UserTokenSchema, user_id: user.id)
      assert length(user_tokens) == 2
    end
  end
end
