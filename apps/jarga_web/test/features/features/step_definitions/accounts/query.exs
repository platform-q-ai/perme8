defmodule Accounts.QuerySteps do
  @moduledoc """
  Step definitions for user lookup and query scenarios.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  alias Jarga.Accounts
  alias Jarga.Accounts.Domain.Entities.User

  # ============================================================================
  # USER LOOKUP
  # ============================================================================

  step "I get the user by email {string}", %{args: [email]} = context do
    user = Accounts.get_user_by_email(email)
    {:ok, Map.put(context, :retrieved_user, user)}
  end

  step "I get the user by email {string} using case-insensitive search",
       %{args: [email]} = context do
    user = Accounts.get_user_by_email_case_insensitive(email)
    {:ok, Map.put(context, :retrieved_user, user)}
  end

  step "I get the user by ID", context do
    user = context[:user]
    retrieved = Accounts.get_user!(user.id)
    {:ok, Map.put(context, :retrieved_user, retrieved)}
  end

  step "I attempt to get a user with non-existent ID", context do
    try do
      Accounts.get_user!(Ecto.UUID.generate())
      {:ok, Map.put(context, :exception_raised, false)}
    rescue
      e in Ecto.NoResultsError ->
        {:ok, Map.put(context, :exception_raised, true) |> Map.put(:exception, e)}
    end
  end

  # ============================================================================
  # EDGE CASES AND SECURITY
  # ============================================================================

  step "I verify a password for a non-existent user", context do
    # This tests timing attack protection - verifying password for nil user
    # should return false without revealing whether user exists
    result = User.valid_password?(nil, "anypassword")

    # Assert that password verification returns false for non-existent user
    assert result == false,
           "Expected password verification to return false for non-existent user"

    {:ok, Map.put(context, :verification_result, result)}
  end
end
