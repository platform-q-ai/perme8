defmodule Jarga.Accounts.Infrastructure.Repositories.UserRepositoryTest do
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures

  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Accounts.Infrastructure.Repositories.UserRepository

  describe "get_by_id/2" do
    test "returns user when ID exists" do
      user = user_fixture()

      assert %User{} = result = UserRepository.get_by_id(user.id)
      assert result.id == user.id
      assert result.email == user.email
    end

    test "returns nil when ID does not exist" do
      fake_id = Ecto.UUID.generate()

      assert UserRepository.get_by_id(fake_id) == nil
    end

    test "accepts custom repo" do
      user = user_fixture()

      assert %User{} = result = UserRepository.get_by_id(user.id, Repo)
      assert result.id == user.id
    end
  end

  describe "get_by_email/2" do
    test "returns user when email exists" do
      user = user_fixture()

      assert %User{} = result = UserRepository.get_by_email(user.email)
      assert result.id == user.id
      assert result.email == user.email
    end

    test "returns user case-insensitively" do
      user = user_fixture(email: "test@example.com")

      assert %User{} = result = UserRepository.get_by_email("TEST@EXAMPLE.COM")
      assert result.id == user.id
    end

    test "returns nil when email does not exist" do
      assert UserRepository.get_by_email("nonexistent@example.com") == nil
    end

    test "accepts custom repo" do
      user = user_fixture()

      assert %User{} = result = UserRepository.get_by_email(user.email, Repo)
      assert result.id == user.id
    end
  end

  describe "exists?/2" do
    test "returns true when user exists" do
      user = user_fixture()

      assert UserRepository.exists?(user.id)
    end

    test "returns false when user does not exist" do
      fake_id = Ecto.UUID.generate()

      refute UserRepository.exists?(fake_id)
    end

    test "accepts custom repo" do
      user = user_fixture()

      assert UserRepository.exists?(user.id, Repo)
    end
  end

  describe "insert/2" do
    test "inserts a user with valid attributes" do
      attrs = %{
        email: "new@example.com",
        first_name: "New",
        last_name: "User",
        hashed_password: "hashed_password_here",
        date_created: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        status: "active"
      }

      assert {:ok, user} = UserRepository.insert(attrs)
      assert user.email == "new@example.com"
      assert user.first_name == "New"
    end

    test "returns error with invalid attributes" do
      attrs = %{email: "invalid"}

      assert {:error, changeset} = UserRepository.insert(attrs)
      refute changeset.valid?
    end

    test "accepts custom repo" do
      attrs = %{
        email: "new@example.com",
        first_name: "New",
        last_name: "User",
        hashed_password: "hashed_password_here",
        date_created: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        status: "active"
      }

      assert {:ok, user} = UserRepository.insert(attrs, Repo)
      assert user.email == "new@example.com"
    end
  end

  describe "update/3" do
    test "updates a user with valid attributes" do
      user = user_fixture()
      attrs = %{first_name: "Updated"}

      assert {:ok, updated_user} = UserRepository.update(user, attrs)
      assert updated_user.first_name == "Updated"
      assert updated_user.id == user.id
    end

    test "returns error with invalid attributes" do
      user = user_fixture()
      attrs = %{email: ""}

      assert {:error, changeset} = UserRepository.update(user, attrs)
      refute changeset.valid?
    end

    test "accepts custom repo" do
      user = user_fixture()
      attrs = %{first_name: "Updated"}

      assert {:ok, updated_user} = UserRepository.update(user, attrs, Repo)
      assert updated_user.first_name == "Updated"
    end
  end
end
