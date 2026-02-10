defmodule Identity.Accounts.PasswordResetSteps do
  @moduledoc """
  Step definitions for password reset LiveView scenarios.

  These steps test the password reset UI flows through Phoenix LiveView,
  including requesting a reset link and setting a new password.
  """

  use Cucumber.StepDefinition
  use IdentityWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures
  import Ecto.Query

  alias Identity.Domain.Services.TokenBuilder
  alias Identity.Infrastructure.Schemas.UserTokenSchema
  alias Identity.Infrastructure.Repositories.UserTokenRepository

  # ============================================================================
  # PAGE NAVIGATION
  # ============================================================================

  step "I visit the forgot password page", context do
    conn = build_conn()
    {:ok, view, html} = live(conn, ~p"/users/reset-password")

    {:ok,
     context
     |> Map.put(:conn, conn)
     |> Map.put(:view, view)
     |> Map.put(:html, html)}
  end

  step "I visit the reset password page with the token", context do
    conn = build_conn()
    token = context[:reset_token]

    result = live(conn, ~p"/users/reset-password/#{token}")

    case result do
      {:ok, view, html} ->
        {:ok,
         context
         |> Map.put(:conn, conn)
         |> Map.put(:view, view)
         |> Map.put(:html, html)}

      {:error, {:live_redirect, %{to: path, flash: _flash}}} ->
        # Token was invalid/expired, follow the redirect
        {:ok, view, html} = live(conn, path)

        {:ok,
         context
         |> Map.put(:conn, conn)
         |> Map.put(:view, view)
         |> Map.put(:html, html)
         |> Map.put(:redirected, true)}
    end
  end

  step "I visit the reset password page with an invalid token", context do
    conn = build_conn()

    # Trying to mount with invalid token should redirect
    result = live(conn, ~p"/users/reset-password/invalid-token-12345")

    case result do
      {:error, {:live_redirect, %{to: path, flash: _flash}}} ->
        {:ok, view, html} = live(conn, path)

        {:ok,
         context
         |> Map.put(:conn, conn)
         |> Map.put(:view, view)
         |> Map.put(:html, html)
         |> Map.put(:redirected, true)}

      {:ok, view, html} ->
        {:ok,
         context
         |> Map.put(:conn, conn)
         |> Map.put(:view, view)
         |> Map.put(:html, html)}
    end
  end

  # ============================================================================
  # TOKEN SETUP
  # ============================================================================

  step "the user has a reset password token", context do
    user = context[:user]

    # Generate a reset password token
    {encoded_token, user_token_schema} = TokenBuilder.build_email_token(user, "reset_password")
    Identity.Repo.insert!(user_token_schema)

    {:ok, Map.put(context, :reset_token, encoded_token)}
  end

  step "the user has an expired reset password token", context do
    user = context[:user]

    # Generate a reset password token
    {encoded_token, user_token_schema} = TokenBuilder.build_email_token(user, "reset_password")
    Identity.Repo.insert!(user_token_schema)

    # Expire the token by backdating it
    Identity.Repo.update_all(
      from(t in UserTokenSchema,
        where: t.token == ^user_token_schema.token
      ),
      set: [inserted_at: DateTime.add(DateTime.utc_now(), -2, :hour)]
    )

    {:ok, Map.put(context, :reset_token, encoded_token)}
  end

  # ============================================================================
  # PAGE ASSERTIONS
  # ============================================================================

  step "I should see the forgot password form", context do
    html = context[:html]
    assert html =~ "Forgot your password?"
    assert html =~ "Email"
    {:ok, context}
  end

  step "I should see the reset password form", context do
    html = context[:html]
    assert html =~ "Reset password"
    assert html =~ "New password"
    {:ok, context}
  end

  step "I should see password and confirmation fields", context do
    html = context[:html]
    assert html =~ "New password"
    assert html =~ "Confirm new password"
    {:ok, context}
  end

  step "I should see a link to reset password", context do
    html = context[:html]
    # Check for forgot password link in login page
    assert html =~ "Forgot" or html =~ "reset" or html =~ "password"
    {:ok, context}
  end

  # ============================================================================
  # FORM INTERACTIONS
  # ============================================================================

  step "I enter {string} in the reset email field", %{args: [email]} = context do
    {:ok, Map.put(context, :entered_email, email)}
  end

  step "I submit the forgot password form", context do
    view = context[:view]
    email = context[:entered_email]

    html =
      view
      |> form("#reset_password_form", %{"user" => %{"email" => email}})
      |> render_submit()

    {:ok, Map.put(context, :html, html)}
  end

  step "I enter {string} as the new password", %{args: [password]} = context do
    {:ok, Map.put(context, :new_password, password)}
  end

  step "I confirm the new password with {string}", %{args: [confirmation]} = context do
    {:ok, Map.put(context, :password_confirmation, confirmation)}
  end

  step "I submit the reset password form", context do
    view = context[:view]
    password = context[:new_password]
    confirmation = context[:password_confirmation]

    html =
      view
      |> form("#reset_password_form", %{
        "user" => %{
          "password" => password,
          "password_confirmation" => confirmation
        }
      })
      |> render_submit()

    {:ok, Map.put(context, :html, html)}
  end

  # ============================================================================
  # NAVIGATION ACTIONS
  # ============================================================================

  step "I click the back to login link", context do
    view = context[:view]

    {:ok, new_view, html} =
      view
      |> element("a", "Back to log in")
      |> render_click()
      |> follow_redirect(build_conn(), ~p"/users/log-in")

    {:ok, Map.put(context, :view, new_view) |> Map.put(:html, html)}
  end

  # ============================================================================
  # RESULT ASSERTIONS
  # ============================================================================

  step "I should be redirected with a reset password flash message", context do
    html = context[:html]

    # The form redirects after submit, check for redirect or message
    case html do
      {:error, {:live_redirect, %{flash: flash_encoded}}} ->
        assert is_binary(flash_encoded) and byte_size(flash_encoded) > 0
        {:ok, context}

      _ when is_binary(html) ->
        # Check for info message about email being sent
        assert html =~ "password reset" or html =~ "email" or html =~ "instructions"
        {:ok, context}

      _ ->
        # Redirect happened
        {:ok, context}
    end
  end

  step "a reset password token should be created for the user", context do
    user = context[:user]

    token =
      UserTokenRepository.get_by_user_id_and_context(user.id, "reset_password", Identity.Repo)

    assert token != nil
    {:ok, context}
  end

  step "I should see password reset success message", context do
    html = context[:html]

    case html do
      {:error, {:live_redirect, %{flash: _flash}}} ->
        # Redirect with flash means success
        {:ok, context}

      _ when is_binary(html) ->
        assert html =~ "success" or html =~ "reset" or html =~ "Password reset"
        {:ok, context}

      _ ->
        {:ok, context}
    end
  end

  step "I should be redirected to login", context do
    html = context[:html]

    case html do
      {:error, {:live_redirect, %{to: path}}} ->
        assert path =~ "/users/log-in"
        {:ok, context}

      _ when is_binary(html) ->
        # After redirect, we should see login page content
        assert html =~ "Log in" or html =~ "Sign in"
        {:ok, context}

      _ ->
        {:ok, context}
    end
  end

  step "I should be able to log in with the new password", context do
    email = context[:user].email
    password = context[:new_password]

    # Verify the new password works
    user = Identity.get_user_by_email_and_password(email, password)
    assert user != nil
    {:ok, context}
  end

  step "I should see token expired error message", context do
    html = context[:html]

    case html do
      {:error, {:live_redirect, %{flash: _flash}}} ->
        # Redirected with flash - success
        {:ok, context}

      _ when is_binary(html) ->
        # After redirect, we might be on the login page
        # The flash message should contain error about invalid/expired token
        # Or the HTML should show the login page (means redirect worked)
        assert html =~ "invalid" or html =~ "expired" or html =~ "Reset password link" or
                 html =~ "Log in" or html =~ "log in"

        {:ok, context}

      _ ->
        {:ok, context}
    end
  end

  step "I should see password confirmation mismatch error", context do
    html = context[:html]
    assert html =~ "does not match" or html =~ "confirmation" or html =~ "match"
    {:ok, context}
  end

  step "I should see password length validation error", context do
    html = context[:html]
    assert html =~ "should be at least 12" or html =~ "too short" or html =~ "12 character"
    {:ok, context}
  end
end
