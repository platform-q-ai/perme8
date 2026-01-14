defmodule Jarga.Accounts.Application.UseCases.UpdateUserPasswordTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures

  alias Jarga.Accounts.Application.UseCases.UpdateUserPassword
  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Accounts.Infrastructure.Schemas.UserTokenSchema
  alias Jarga.Accounts.Domain.Services.TokenBuilder
  alias Jarga.Accounts.Infrastructure.Schemas.UserSchema

  describe "execute/2" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "updates password successfully", %{user: user} do
      attrs = %{
        password: "new valid password",
        password_confirmation: "new valid password"
      }

      assert {:ok, {%User{} = updated_user, expired_tokens}} =
               UpdateUserPassword.execute(%{user: user, attrs: attrs})

      assert updated_user.id == user.id
      assert is_list(expired_tokens)
      # Password should be hashed
      assert updated_user.hashed_password != user.hashed_password
      # New password should work
      assert User.valid_password?(updated_user, "new valid password")
    end

    test "hashes password using PasswordService", %{user: user} do
      attrs = %{
        password: "new valid password",
        password_confirmation: "new valid password"
      }

      # Create a mock PasswordService that returns a known hash
      mock_password_service = fn password ->
        "mock_hashed_" <> password
      end

      assert {:ok, {updated_user, _tokens}} =
               UpdateUserPassword.execute(
                 %{user: user, attrs: attrs},
                 password_service: mock_password_service
               )

      assert updated_user.hashed_password == "mock_hashed_new valid password"
    end

    test "deletes all user tokens after update", %{user: user} do
      # Create some tokens for the user
      {_session_token, session_user_token} = TokenBuilder.build_session_token(user)
      {_email_token, email_user_token} = TokenBuilder.build_email_token(user, "confirm")

      Repo.insert!(session_user_token)
      Repo.insert!(email_user_token)

      # Verify tokens exist
      assert length(Repo.all_by(UserTokenSchema, user_id: user.id)) == 2

      attrs = %{
        password: "new valid password",
        password_confirmation: "new valid password"
      }

      assert {:ok, {_updated_user, expired_tokens}} =
               UpdateUserPassword.execute(%{user: user, attrs: attrs})

      # All tokens should be expired
      assert length(expired_tokens) == 2

      # No tokens should remain in database
      assert Repo.all_by(UserTokenSchema, user_id: user.id) == []
    end

    test "returns expired tokens list", %{user: user} do
      # Create multiple tokens
      {_token1, user_token1} = TokenBuilder.build_session_token(user)
      {_token2, user_token2} = TokenBuilder.build_email_token(user, "confirm")
      {_token3, user_token3} = TokenBuilder.build_email_token(user, "login")

      inserted_token1 = Repo.insert!(user_token1)
      inserted_token2 = Repo.insert!(user_token2)
      inserted_token3 = Repo.insert!(user_token3)

      attrs = %{
        password: "new valid password",
        password_confirmation: "new valid password"
      }

      assert {:ok, {_updated_user, expired_tokens}} =
               UpdateUserPassword.execute(%{user: user, attrs: attrs})

      # Should return all 3 expired tokens
      assert length(expired_tokens) == 3
      token_ids = Enum.map(expired_tokens, & &1.id) |> Enum.sort()
      expected_ids = [inserted_token1.id, inserted_token2.id, inserted_token3.id] |> Enum.sort()
      assert token_ids == expected_ids
    end

    test "rolls back transaction on failure", %{user: user} do
      # Create a token to verify rollback
      {_token, user_token} = TokenBuilder.build_session_token(user)
      Repo.insert!(user_token)

      # Use invalid attrs to force failure
      attrs = %{
        password: "short",
        password_confirmation: "short"
      }

      assert {:error, %Ecto.Changeset{}} =
               UpdateUserPassword.execute(%{user: user, attrs: attrs})

      # Token should still exist (transaction rolled back)
      assert length(Repo.all_by(UserTokenSchema, user_id: user.id)) == 1
      # User password should be unchanged
      assert Repo.get!(UserSchema, user.id).hashed_password == user.hashed_password
    end

    test "returns error for invalid password", %{user: user} do
      attrs = %{
        password: "short",
        password_confirmation: "short"
      }

      assert {:error, changeset} = UpdateUserPassword.execute(%{user: user, attrs: attrs})
      assert %Ecto.Changeset{valid?: false} = changeset
      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end

    test "returns error when password confirmation doesn't match", %{user: user} do
      attrs = %{
        password: "new valid password",
        password_confirmation: "different password"
      }

      assert {:error, changeset} = UpdateUserPassword.execute(%{user: user, attrs: attrs})
      assert %Ecto.Changeset{valid?: false} = changeset
      assert "does not match password" in errors_on(changeset).password_confirmation
    end
  end
end
