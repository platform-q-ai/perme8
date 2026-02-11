defmodule Identity.Accounts.VerifyRegistrationSteps do
  @moduledoc """
  Step definitions for user registration verification and assertions.
  """

  use Cucumber.StepDefinition
  use IdentityWeb.ConnCase, async: false

  alias Identity.Infrastructure.Repositories.UserRepository

  # ============================================================================
  # REGISTRATION ASSERTIONS
  # ============================================================================

  step "the registration should be successful", context do
    assert {:ok, _user} = context[:registration_result]
    {:ok, context}
  end

  step "the registration should fail", context do
    assert {:error, _changeset} = context[:registration_result]
    {:ok, context}
  end

  step "the user should have email {string}", %{args: [email]} = context do
    user = context[:user]
    assert user.email == email
    {:ok, context}
  end

  step "the user should have first name {string}", %{args: [first_name]} = context do
    user = context[:user]
    assert user.first_name == first_name
    {:ok, context}
  end

  step "the user should have last name {string}", %{args: [last_name]} = context do
    user = context[:user]
    assert user.last_name == last_name
    {:ok, context}
  end

  step "the user should have status {string}", %{args: [status]} = context do
    user = context[:user]
    assert user.status == status
    {:ok, context}
  end

  step "the user should not be confirmed", context do
    user = context[:user]
    assert is_nil(user.confirmed_at)
    {:ok, context}
  end

  step "the user should be confirmed", context do
    user = UserRepository.get_by_id(context[:user].id)
    refute is_nil(user.confirmed_at)
    {:ok, Map.put(context, :user, user)}
  end

  step "the password should be hashed with bcrypt", context do
    user = context[:user]
    assert String.starts_with?(user.hashed_password, "$2b$")
    {:ok, context}
  end

  step "I should see validation errors for {string}", %{args: [field]} = context do
    changeset = context[:changeset]
    field_atom = String.to_atom(field)
    assert Keyword.has_key?(changeset.errors, field_atom)
    {:ok, context}
  end

  step "I should see an email format validation error", context do
    changeset = context[:changeset]
    assert Keyword.has_key?(changeset.errors, :email)
    {:ok, context}
  end

  step "I should see a password length validation error", context do
    changeset = context[:changeset]
    assert Keyword.has_key?(changeset.errors, :password)
    {:ok, context}
  end

  step "I should see a duplicate email error", context do
    changeset = context[:changeset]
    assert Keyword.has_key?(changeset.errors, :email)
    {:ok, context}
  end

  step "the user email should be {string}", %{args: [email]} = context do
    user = context[:user]
    assert user.email == email
    {:ok, context}
  end

  step "the user email should be stored as {string}", %{args: [email]} = context do
    user = context[:user]
    assert user.email == email
    {:ok, context}
  end

  # ============================================================================
  # LOGIN ASSERTIONS
  # ============================================================================

  step "the login should be successful", context do
    assert context[:login_result] == :ok
    {:ok, context}
  end

  step "the login should fail", context do
    assert match?({:error, _}, context[:login_result])
    {:ok, context}
  end

  step "the login should fail with error {string}", %{args: [error]} = context do
    expected_error = String.to_atom(error)
    assert context[:login_result] == {:error, expected_error}
    {:ok, context}
  end

  step "I should receive the user record", context do
    # Check both login_user (for password auth) and retrieved_user (for session token)
    user = context[:login_user] || context[:retrieved_user]
    assert user != nil
    {:ok, context}
  end

  step "I should not receive a user record", context do
    # Check both login_user (for password auth) and retrieved_user (for session token)
    user = context[:login_user] || context[:retrieved_user]
    assert user == nil
    {:ok, context}
  end

  # ============================================================================
  # TIMESTAMP ASSERTIONS
  # ============================================================================

  step "the user should have a date_created timestamp", context do
    user = context[:user]
    assert user.date_created != nil
    {:ok, context}
  end

  step "the timestamp should be within {int} seconds of now", %{args: [seconds]} = context do
    user = context[:user]
    now = NaiveDateTime.utc_now()
    diff = NaiveDateTime.diff(now, user.date_created, :second)
    assert abs(diff) <= seconds
    {:ok, context}
  end
end
