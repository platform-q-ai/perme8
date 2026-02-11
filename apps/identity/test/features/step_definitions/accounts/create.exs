defmodule Identity.Accounts.CreateSteps do
  @moduledoc """
  Step definitions for user registration scenarios.

  NOTE: Uses Jarga.Accounts for domain operations to ensure consistent entity types.
  """

  use Cucumber.StepDefinition
  use IdentityWeb.ConnCase, async: false

  import Jarga.AccountsFixtures

  alias Jarga.Accounts

  # ============================================================================
  # USER REGISTRATION
  # ============================================================================

  step "I register with the following details:", context do
    attrs =
      context.datatable.maps
      |> Enum.map(fn row -> {String.to_atom(row["Field"]), row["Value"]} end)
      |> Enum.into(%{})

    result = Accounts.register_user(attrs)

    case result do
      {:ok, user} ->
        Map.put(context, :user, user) |> Map.put(:registration_result, result)

      {:error, changeset} ->
        Map.put(context, :registration_result, result) |> Map.put(:changeset, changeset)
    end
  end

  step "I attempt to register with the following details:", context do
    attrs =
      context.datatable.maps
      |> Enum.map(fn row -> {String.to_atom(row["Field"]), row["Value"]} end)
      |> Enum.into(%{})

    result = Accounts.register_user(attrs)

    case result do
      {:ok, user} ->
        Map.put(context, :user, user) |> Map.put(:registration_result, result)

      {:error, changeset} ->
        Map.put(context, :registration_result, result) |> Map.put(:changeset, changeset)
    end
  end

  step "I register with email {string}", %{args: [email]} = context do
    attrs = %{
      email: email,
      password: "SecurePassword123!",
      first_name: "Test",
      last_name: "User"
    }

    result = Accounts.register_user(attrs)

    case result do
      {:ok, user} ->
        Map.put(context, :user, user) |> Map.put(:registration_result, result)

      {:error, changeset} ->
        Map.put(context, :registration_result, result) |> Map.put(:changeset, changeset)
    end
  end

  step "I register a new user", context do
    attrs = %{
      email: unique_user_email(),
      password: "SecurePassword123!",
      first_name: "Test",
      last_name: "User"
    }

    result = Accounts.register_user(attrs)

    case result do
      {:ok, user} ->
        Map.put(context, :user, user) |> Map.put(:registration_result, result)

      {:error, changeset} ->
        Map.put(context, :registration_result, result) |> Map.put(:changeset, changeset)
    end
  end
end
