defmodule IdentityWeb.SessionController do
  use IdentityWeb, :controller

  alias Identity
  alias IdentityWeb.Plugs.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, "User confirmed successfully.")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Identity.login_user_by_magic_link(token) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        # Create notifications for any pending workspace invitations
        # This ensures new users see invitations sent before they signed up
        # Note: Uses apply/3 to avoid compile-time warning since Jarga.Workspaces
        # is in a different app that may not be available during compilation
        if Code.ensure_loaded?(Jarga.Workspaces) and
             function_exported?(
               Jarga.Workspaces,
               :create_notifications_for_pending_invitations,
               1
             ) do
          # credo:disable-for-next-line Credo.Check.Refactor.Apply
          apply(Jarga.Workspaces, :create_notifications_for_pending_invitations, [user])
        end

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # email + password login
  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Identity.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log-in")
    end
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user

    if Identity.sudo_mode?(user) do
      {:ok, {_user, expired_tokens}} = Identity.update_user_password(user, user_params)

      # disconnect all existing LiveViews with old sessions
      UserAuth.disconnect_sessions(expired_tokens)

      conn
      |> put_session(:user_return_to, ~p"/users/settings")
      |> create(params, "Password updated successfully!")
    else
      conn
      |> put_flash(:error, "Session expired. Please reauthenticate.")
      |> redirect(to: ~p"/users/log-in")
      |> halt()
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
