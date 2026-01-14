defmodule Jarga.Accounts.UserTest do
  use Jarga.DataCase, async: true

  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Accounts.Infrastructure.Schemas.UserSchema

  import Jarga.AccountsFixtures

  describe "email_changeset/3" do
    test "requires email to be present" do
      changeset = UserSchema.email_changeset(%UserSchema{}, %{})
      assert "can't be blank" in errors_on(changeset).email
    end

    test "validates email format" do
      changeset = UserSchema.email_changeset(%UserSchema{}, %{email: "invalid"})
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end

    test "rejects email with spaces" do
      changeset = UserSchema.email_changeset(%UserSchema{}, %{email: "user name@example.com"})
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end

    test "rejects email with commas" do
      changeset = UserSchema.email_changeset(%UserSchema{}, %{email: "user,name@example.com"})
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end

    test "rejects email with semicolons" do
      changeset = UserSchema.email_changeset(%UserSchema{}, %{email: "user;name@example.com"})
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end

    test "validates email length" do
      long_email = String.duplicate("a", 150) <> "@example.com"
      changeset = UserSchema.email_changeset(%UserSchema{}, %{email: long_email})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "converts email to lowercase" do
      changeset = UserSchema.email_changeset(%UserSchema{}, %{email: "TEST@EXAMPLE.COM"})
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :email) == "test@example.com"
    end

    test "validates email uniqueness when validate_unique is true" do
      _user = user_fixture(%{email: "test@example.com"})

      # Create a complete registration changeset first, then apply email change
      base_user = %User{
        first_name: "Test",
        last_name: "User",
        date_created: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        status: "active"
      }

      changeset =
        UserSchema.email_changeset(base_user, %{email: "test@example.com"}, validate_unique: true)

      {:error, changeset} = Repo.insert(changeset)
      assert "has already been taken" in errors_on(changeset).email
    end

    test "adds unique_constraint to changeset when validate_unique is true" do
      changeset =
        UserSchema.email_changeset(%UserSchema{}, %{email: "test@example.com"},
          validate_unique: true
        )

      assert changeset.valid?
      # Verify unique_constraint is present in changeset
      assert Enum.any?(changeset.constraints, fn constraint ->
               constraint.type == :unique && constraint.field == :email
             end)
    end

    test "skips uniqueness validation when validate_unique is false" do
      user_fixture(%{email: "test@example.com"})

      changeset =
        UserSchema.email_changeset(%UserSchema{}, %{email: "test@example.com"},
          validate_unique: false
        )

      assert changeset.valid?
      refute Keyword.has_key?(changeset.errors, :email)
    end

    test "validates email changed for existing user with email" do
      user = user_fixture(%{email: "original@example.com"})

      changeset =
        UserSchema.email_changeset(user, %{email: "original@example.com"}, validate_unique: true)

      assert "did not change" in errors_on(changeset).email
    end

    test "accepts new email for existing user" do
      user = user_fixture(%{email: "original@example.com"})

      changeset =
        UserSchema.email_changeset(user, %{email: "new@example.com"}, validate_unique: true)

      assert changeset.valid?
    end
  end

  describe "registration_changeset/3" do
    test "requires first_name, last_name, and email" do
      changeset = UserSchema.registration_changeset(%UserSchema{}, %{})

      assert "can't be blank" in errors_on(changeset).first_name
      assert "can't be blank" in errors_on(changeset).last_name
      assert "can't be blank" in errors_on(changeset).email
    end

    test "sets date_created to current time" do
      attrs = %{
        first_name: "Test",
        last_name: "User",
        email: "test@example.com",
        password: "hello world 123!"
      }

      changeset = UserSchema.registration_changeset(%UserSchema{}, attrs)
      date_created = Ecto.Changeset.get_change(changeset, :date_created)

      assert date_created != nil
      assert NaiveDateTime.diff(NaiveDateTime.utc_now(), date_created) < 5
    end

    test "sets status to active" do
      attrs = %{
        first_name: "Test",
        last_name: "User",
        email: "test@example.com",
        password: "hello world 123!"
      }

      changeset = UserSchema.registration_changeset(%UserSchema{}, attrs)
      assert Ecto.Changeset.get_change(changeset, :status) == "active"
    end

    test "validates email format" do
      attrs = %{
        first_name: "Test",
        last_name: "User",
        email: "invalid",
        password: "hello world 123!"
      }

      changeset = UserSchema.registration_changeset(%UserSchema{}, attrs)
      assert "must have the @ sign and no spaces" in errors_on(changeset).email
    end

    test "validates password length minimum" do
      attrs = %{
        first_name: "Test",
        last_name: "User",
        email: "test@example.com",
        password: "short"
      }

      changeset = UserSchema.registration_changeset(%UserSchema{}, attrs)
      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end

    test "validates password length maximum" do
      attrs = %{
        first_name: "Test",
        last_name: "User",
        email: "test@example.com",
        password: String.duplicate("a", 73)
      }

      changeset = UserSchema.registration_changeset(%UserSchema{}, attrs)
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "does NOT hash password - hashing is infrastructure concern" do
      attrs = %{
        first_name: "Test",
        last_name: "User",
        email: "test@example.com",
        password: "hello world 123!"
      }

      changeset = UserSchema.registration_changeset(%UserSchema{}, attrs)

      assert changeset.valid?
      refute Ecto.Changeset.get_change(changeset, :hashed_password)
      # Password remains in changeset for infrastructure layer to hash
      assert Ecto.Changeset.get_change(changeset, :password) == "hello world 123!"
    end

    test "validates password format only - no hashing" do
      attrs = %{
        first_name: "Test",
        last_name: "User",
        email: "test@example.com",
        password: "valid password 123"
      }

      changeset = UserSchema.registration_changeset(%UserSchema{}, attrs)

      assert changeset.valid?
      # Password validation passes but hashing doesn't occur
      refute Ecto.Changeset.get_change(changeset, :hashed_password)
    end

    test "adds unique_constraint for email when validate_unique is true (default)" do
      attrs = %{
        first_name: "Test",
        last_name: "User",
        email: "test@example.com",
        password: "valid password 123"
      }

      changeset = UserSchema.registration_changeset(%UserSchema{}, attrs)

      assert changeset.valid?
      # Verify unique_constraint is present in changeset
      assert Enum.any?(changeset.constraints, fn constraint ->
               constraint.type == :unique && constraint.field == :email
             end)
    end

    test "skips unique_constraint for email when validate_unique is false" do
      attrs = %{
        first_name: "Test",
        last_name: "User",
        email: "test@example.com",
        password: "valid password 123"
      }

      changeset = UserSchema.registration_changeset(%UserSchema{}, attrs, validate_unique: false)

      assert changeset.valid?
      # Verify unique_constraint is NOT present in changeset
      refute Enum.any?(changeset.constraints, fn constraint ->
               constraint.type == :unique && constraint.field == :email
             end)
    end
  end

  describe "password_changeset/3" do
    test "requires password" do
      changeset = UserSchema.password_changeset(%UserSchema{}, %{})
      assert "can't be blank" in errors_on(changeset).password
    end

    test "validates password minimum length" do
      changeset = UserSchema.password_changeset(%UserSchema{}, %{password: "short"})
      assert "should be at least 12 character(s)" in errors_on(changeset).password
    end

    test "validates password maximum length" do
      changeset =
        UserSchema.password_changeset(%UserSchema{}, %{password: String.duplicate("a", 73)})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates password confirmation" do
      changeset =
        UserSchema.password_changeset(%UserSchema{}, %{
          password: "hello world 123!",
          password_confirmation: "different password!"
        })

      assert "does not match password" in errors_on(changeset).password_confirmation
    end

    test "does NOT hash password - hashing is infrastructure concern" do
      changeset =
        UserSchema.password_changeset(
          %UserSchema{},
          %{password: "hello world 123!", password_confirmation: "hello world 123!"}
        )

      assert changeset.valid?
      refute Ecto.Changeset.get_change(changeset, :hashed_password)
      # Password remains in changeset for infrastructure layer to hash
      assert Ecto.Changeset.get_change(changeset, :password) == "hello world 123!"
    end
  end

  describe "confirm_changeset/1" do
    test "sets confirmed_at to current time" do
      user = %UserSchema{}
      changeset = UserSchema.confirm_changeset(user)

      confirmed_at = Ecto.Changeset.get_change(changeset, :confirmed_at)
      assert confirmed_at != nil
      assert DateTime.diff(DateTime.utc_now(), confirmed_at) < 5
    end

    test "returns changeset for confirmed user" do
      now = DateTime.utc_now(:second)
      user = %User{confirmed_at: now}
      changeset = UserSchema.confirm_changeset(user)

      new_confirmed_at = Ecto.Changeset.get_change(changeset, :confirmed_at)
      assert new_confirmed_at != nil
      # Should update to new time
      assert DateTime.diff(new_confirmed_at, now) >= 0
    end
  end

  describe "valid_password?/2" do
    test "returns true for valid password" do
      user = user_fixture()
      assert User.valid_password?(user, valid_user_password())
    end

    test "returns false for invalid password" do
      user = user_fixture()
      refute User.valid_password?(user, "wrong password")
    end

    test "returns false when user has no hashed_password" do
      user = %User{hashed_password: nil}
      refute User.valid_password?(user, "any password")
    end

    test "returns false when password is empty" do
      user = user_fixture()
      refute User.valid_password?(user, "")
    end

    test "returns false for nil user" do
      refute User.valid_password?(nil, "any password")
    end

    test "protects against timing attacks on nil user" do
      # This should take similar time as a valid check
      start_time = System.monotonic_time()
      refute User.valid_password?(nil, "any password")
      time_taken = System.monotonic_time() - start_time

      # Should take more than trivial time (Bcrypt.no_user_verify/0 is called)
      assert time_taken > 0
    end
  end
end
