defmodule IdentityWeb.ForgotPasswordLive do
  @moduledoc """
  LiveView for requesting password reset instructions.

  Users enter their email address to receive a password reset link.
  The email is always indicated as sent to prevent email enumeration attacks.
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
            Forgot your password?
            <:subtitle>
              We'll send a password reset link to your inbox.
            </:subtitle>
          </.header>
        </div>

        <div :if={local_mail_adapter?()} class="alert alert-info">
          <.icon name="hero-information-circle" class="size-6 shrink-0" />
          <div>
            <p>You are running the local mail adapter.</p>
            <p>
              To see sent emails, visit <.link href="/dev/mailbox" class="underline">the mailbox page</.link>.
            </p>
          </div>
        </div>

        <.form for={@form} id="reset_password_form" phx-submit="submit">
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            autocomplete="email"
            required
            phx-mounted={JS.focus()}
          />
          <.button variant="primary" class="w-full">
            Send password reset instructions
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
  def mount(_params, _session, socket) do
    form = to_form(%{"email" => ""}, as: "user")
    {:ok, assign(socket, form: form)}
  end

  @impl true
  def handle_event("submit", %{"user" => %{"email" => email}}, socket) do
    if user = Identity.get_user_by_email(email) do
      Identity.deliver_reset_password_instructions(
        user,
        &url(~p"/users/reset-password/#{&1}")
      )
    end

    # Always show the same message to prevent email enumeration
    info =
      "If your email is in our system, you will receive password reset instructions shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:identity, Identity.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
