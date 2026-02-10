defmodule Identity.Accounts.UpdateSteps do
  @moduledoc """
  Step definitions for user account update scenarios (password, email).

  NOTE: Uses Jarga.Accounts for domain operations to ensure consistent entity types.
  """

  use Cucumber.StepDefinition
  use IdentityWeb.ConnCase, async: false

  import Jarga.AccountsFixtures

  alias Jarga.Accounts
  alias Jarga.Accounts.Infrastructure.Repositories.UserTokenRepository

  # ============================================================================
  # PASSWORD UPDATES
  # ============================================================================

  step "I update the password to {string} with confirmation {string}",
       %{args: [password, confirmation]} = context do
    user = context[:user]
    attrs = %{password: password, password_confirmation: confirmation}
    result = Accounts.update_user_password(user, attrs)

    case result do
      {:ok, {updated_user, expired_tokens}} ->
        Map.put(context, :user, updated_user)
        |> Map.put(:expired_tokens, expired_tokens)
        |> Map.put(:password_update_result, :ok)

      {:error, changeset} ->
        Map.put(context, :changeset, changeset)
        |> Map.put(:password_update_result, :error)
    end
  end

  step "I attempt to update the password to {string} with confirmation {string}",
       %{args: [password, confirmation]} = context do
    user = context[:user]
    attrs = %{password: password, password_confirmation: confirmation}
    result = Accounts.update_user_password(user, attrs)

    case result do
      {:ok, {updated_user, expired_tokens}} ->
        Map.put(context, :user, updated_user)
        |> Map.put(:expired_tokens, expired_tokens)
        |> Map.put(:password_update_result, :ok)

      {:error, changeset} ->
        Map.put(context, :changeset, changeset)
        |> Map.put(:password_update_result, :error)
    end
  end

  step "the password update fails during transaction", context do
    user = context[:user]

    # Store the original password hash for comparison
    original_hash = user.hashed_password

    # Create a session token to verify it doesn't get deleted
    token = Accounts.generate_user_session_token(user)

    token_count_before = UserTokenRepository.count_by_user_id(user.id)

    # Attempt to update with invalid data (this will fail)
    result =
      Accounts.update_user_password(user, %{
        # Too short - will fail validation
        password: "x",
        password_confirmation: "x"
      })

    {:ok,
     context
     |> Map.put(:original_hash, original_hash)
     |> Map.put(:token_count_before, token_count_before)
     |> Map.put(:password_update_result, result)
     |> Map.put(:test_session_token, token)}
  end

  # ============================================================================
  # EMAIL UPDATES
  # ============================================================================

  step "an email change token is generated for changing to {string}",
       %{args: [new_email]} = context do
    user = context[:user]
    current_email = user.email

    encoded_token =
      extract_user_token(fn url ->
        Accounts.deliver_user_update_email_instructions(
          %{user | email: new_email},
          current_email,
          url
        )
      end)

    {:ok, Map.put(context, :email_change_token, encoded_token) |> Map.put(:new_email, new_email)}
  end

  step "I update the email using the change token", context do
    user = context[:user]
    token = context[:email_change_token]
    result = Accounts.update_user_email(user, token)

    case result do
      {:ok, updated_user} ->
        Map.put(context, :user, updated_user) |> Map.put(:email_update_result, :ok)

      {:error, reason} ->
        Map.put(context, :email_update_result, {:error, reason})
    end
  end

  step "I attempt to update the email with an invalid token", context do
    user = context[:user]
    result = Accounts.update_user_email(user, "invalid_token")

    case result do
      {:ok, updated_user} ->
        Map.put(context, :user, updated_user) |> Map.put(:email_update_result, :ok)

      {:error, reason} ->
        Map.put(context, :email_update_result, {:error, reason})
    end
  end

  step "I attempt to update the email using the change token", context do
    user = context[:user]
    token = context[:email_change_token]
    result = Accounts.update_user_email(user, token)

    case result do
      {:ok, updated_user} ->
        Map.put(context, :user, updated_user) |> Map.put(:email_update_result, :ok)

      {:error, reason} ->
        Map.put(context, :email_update_result, {:error, reason})
    end
  end

  # ============================================================================
  # EMAIL DELIVERY
  # ============================================================================

  step "I request login instructions for {string}", %{args: [email]} = context do
    user = context[:user] || Accounts.get_user_by_email(email)

    token =
      extract_user_token(fn url ->
        Accounts.deliver_login_instructions(user, url)
      end)

    {:ok, Map.put(context, :login_token, token) |> Map.put(:user, user)}
  end

  step "I request email update instructions for changing to {string}",
       %{args: [new_email]} = context do
    user = context[:user]
    current_email = user.email

    token =
      extract_user_token(fn url ->
        Accounts.deliver_user_update_email_instructions(
          %{user | email: new_email},
          current_email,
          url
        )
      end)

    {:ok,
     Map.put(context, :email_change_token, token)
     |> Map.put(:new_email, new_email)}
  end

  # ============================================================================
  # CHANGESET HELPERS
  # ============================================================================

  step "I generate an email changeset with new email {string}", %{args: [new_email]} = context do
    user = context[:user]
    changeset = Accounts.change_user_email(user, %{email: new_email})
    {:ok, Map.put(context, :changeset, changeset)}
  end

  step "I generate a password changeset with new password {string}",
       %{args: [new_password]} = context do
    user = context[:user]
    changeset = Accounts.change_user_password(user, %{password: new_password})
    {:ok, Map.put(context, :changeset, changeset)}
  end
end
