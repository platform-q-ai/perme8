defmodule Jarga.Accounts.Application.UseCases.RegisterUserTest do
  use Jarga.DataCase, async: true

  alias Jarga.Accounts.Application.UseCases.RegisterUser
  alias Jarga.Accounts.Domain.Entities.User

  describe "execute/2" do
    test "registers user successfully with valid attributes" do
      attrs = %{
        email: "test@example.com",
        password: "valid_password_123",
        first_name: "John",
        last_name: "Doe"
      }

      assert {:ok, %User{} = user} = RegisterUser.execute(%{attrs: attrs})
      assert user.email == "test@example.com"
      assert user.first_name == "John"
      assert user.last_name == "Doe"
      assert user.confirmed_at == nil
      assert user.hashed_password != nil
      assert user.hashed_password != "valid_password_123"
      assert user.date_created != nil
      assert user.status == "active"
    end

    test "returns error with invalid attributes" do
      attrs = %{
        email: "invalid-email",
        password: "short",
        first_name: "",
        last_name: ""
      }

      assert {:error, %Ecto.Changeset{} = changeset} = RegisterUser.execute(%{attrs: attrs})
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
      assert "should be at least 12 character(s)" in errors_on(changeset).password
      assert "can't be blank" in errors_on(changeset).first_name
      assert "can't be blank" in errors_on(changeset).last_name
    end

    test "hashes password using PasswordService" do
      attrs = %{
        email: "test@example.com",
        password: "plain_password_123",
        first_name: "Jane",
        last_name: "Smith"
      }

      assert {:ok, %User{} = user} = RegisterUser.execute(%{attrs: attrs})

      # Password should be hashed (not plain text)
      assert user.hashed_password != "plain_password_123"
      assert String.starts_with?(user.hashed_password, "$2b$")
    end

    test "validates email uniqueness" do
      attrs = %{
        email: "duplicate@example.com",
        password: "valid_password_123",
        first_name: "First",
        last_name: "User"
      }

      # First registration should succeed
      assert {:ok, _user} = RegisterUser.execute(%{attrs: attrs})

      # Second registration with same email should fail
      assert {:error, %Ecto.Changeset{} = changeset} = RegisterUser.execute(%{attrs: attrs})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "sets date_created and status on registration" do
      attrs = %{
        email: "newuser@example.com",
        password: "valid_password_123",
        first_name: "New",
        last_name: "User"
      }

      before = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      assert {:ok, %User{} = user} = RegisterUser.execute(%{attrs: attrs})
      after_time = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      assert user.status == "active"
      assert user.date_created != nil
      assert NaiveDateTime.compare(user.date_created, before) in [:eq, :gt]
      assert NaiveDateTime.compare(user.date_created, after_time) in [:eq, :lt]
    end

    test "accepts injectable repo for testing" do
      # This test verifies the use case accepts a :repo option
      # In real tests, we'd use this with a mock repo
      attrs = %{
        email: "injectable@example.com",
        password: "valid_password_123",
        first_name: "Test",
        last_name: "User"
      }

      # Using default repo (Jarga.Repo)
      assert {:ok, %User{}} = RegisterUser.execute(%{attrs: attrs}, repo: Jarga.Repo)
    end

    test "accepts injectable password_service for testing" do
      # This test verifies the use case accepts a :password_service option
      attrs = %{
        email: "password_service@example.com",
        password: "valid_password_123",
        first_name: "Test",
        last_name: "User"
      }

      # Using default password service
      assert {:ok, %User{}} =
               RegisterUser.execute(%{attrs: attrs},
                 password_service: Jarga.Accounts.Application.Services.PasswordService
               )
    end
  end
end
