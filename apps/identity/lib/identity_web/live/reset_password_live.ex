defmodule IdentityWeb.ResetPasswordLive do
  @moduledoc """
  LiveView for resetting a user's password.

  Users access this page via a token received in their email.
  The token is verified, and if valid, the user can set a new password.
  """
  use IdentityWeb, :live_view

  alias Identity

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            Reset password
            <:subtitle>
              Enter a new password for your account.
            </:subtitle>
          </.header>
        </div>

        <.form
          for={@form}
          id="reset_password_form"
          phx-submit="reset_password"
          phx-change="validate"
          novalidate
        >
          <.input
            field={@form[:password]}
            type="password"
            label="New password"
            autocomplete="new-password"
            required
            phx-mounted={JS.focus()}
          />
          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirm new password"
            autocomplete="new-password"
            required
          />
          <.button variant="primary" class="w-full" phx-disable-with="Resetting...">
            Reset password
          </.button>
        </.form>

        <p class="text-center text-sm text-gray-600">
          <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
            Back to log in
          </.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Identity.get_user_by_reset_password_token(token) do
      form = to_form(%{"password" => "", "password_confirmation" => ""}, as: "user")

      {:ok,
       socket
       |> assign(:token, token)
       |> assign(:user, user)
       |> assign(:form, form), temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Reset password link is invalid or it has expired.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      Identity.change_user_password(socket.assigns.user, user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: "user"))}
  end

  def handle_event("reset_password", %{"user" => user_params}, socket) do
    case Identity.reset_user_password(socket.assigns.token, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, :invalid_token} ->
        {:noreply,
         socket
         |> put_flash(:error, "Reset password link is invalid or it has expired.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "user"))}
    end
  end
end
