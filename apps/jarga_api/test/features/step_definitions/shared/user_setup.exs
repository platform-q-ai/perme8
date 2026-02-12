defmodule JargaApi.Shared.UserSetupSteps do
  @moduledoc """
  Shared step definitions for user account test setup.

  These steps are used by workspace, project, and other feature tests
  that need user fixtures but aren't specifically testing account functionality.

  Adapted for jarga_api: uses JargaApi.ConnCase instead of JargaWeb.ConnCase.
  """

  use Cucumber.StepDefinition
  use JargaApi.ConnCase, async: false

  import Jarga.AccountsFixtures

  alias Jarga.Accounts
  alias JargaApi.Test.Helpers

  # ============================================================================
  # USER SETUP - Data Table step for Background sections
  # ============================================================================

  step "the following users exist:", context do
    Helpers.ensure_sandbox_checkout()

    table_data = context.datatable.maps

    users =
      Enum.reduce(table_data, Map.get(context, :users, %{}), fn row, acc ->
        email = row["Email"]
        name = row["Name"]

        user =
          case Accounts.get_user_by_email(email) do
            nil ->
              attrs = %{email: email}

              attrs =
                if name do
                  first_name =
                    name
                    |> String.split(" ")
                    |> List.first()

                  Map.put(attrs, :first_name, first_name)
                else
                  attrs
                end

              user_fixture(attrs)

            existing_user ->
              existing_user
          end

        Map.put(acc, email, user)
      end)

    context
    |> Map.put(:users, users)
  end

  # ============================================================================
  # SINGLE USER SETUP STEPS
  # ============================================================================

  step "a user exists with email {string}", %{args: [email]} = context do
    Helpers.ensure_sandbox_checkout()
    user = get_or_create_user(email)
    {:ok, Map.put(context, :user, user)}
  end

  step "a confirmed user exists with email {string}", %{args: [email]} = context do
    Helpers.ensure_sandbox_checkout()
    user = get_or_create_user(email)
    {:ok, Map.put(context, :user, user)}
  end

  step "a confirmed user exists with email {string} and password {string}",
       %{args: [email, password]} = context do
    Helpers.ensure_sandbox_checkout()
    user = get_or_create_user_with_password(email, password)
    {:ok, Map.put(context, :user, user) |> Map.put(:password, password)}
  end

  # ============================================================================
  # HELPERS
  # ============================================================================

  defp get_or_create_user(email) do
    case Accounts.get_user_by_email(email) do
      nil -> user_fixture(%{email: email})
      existing_user -> existing_user
    end
  end

  defp get_or_create_user_with_password(email, password) do
    case Accounts.get_user_by_email(email) do
      nil ->
        user_fixture(%{email: email, password: password})

      existing_user ->
        existing_user
    end
  end
end
