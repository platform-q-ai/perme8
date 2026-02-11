defmodule Identity.Infrastructure.Notifiers.UserNotifier do
  @moduledoc """
  Delivers email notifications for user account actions.
  """

  @behaviour Identity.Application.Behaviours.UserNotifierBehaviour

  import Swoosh.Email

  alias Identity.Mailer
  alias Identity.Domain.Entities.User

  # Delivers the email using the application mailer.
  # Configuration can be injected via opts or falls back to Application config or defaults
  defp deliver(recipient, subject, body, opts) do
    from_email = Keyword.get(opts, :from_email, default_from_email())
    from_name = Keyword.get(opts, :from_name, default_from_name())

    email =
      new()
      |> to(recipient)
      |> from({from_name, from_email})
      |> subject(subject)
      |> text_body(body)
      |> maybe_disable_tracking(opts)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  defp default_from_email do
    Application.get_env(:jarga, :mailer_from_email, "noreply@jarga.app")
  end

  defp default_from_name do
    Application.get_env(:jarga, :mailer_from_name, "Jarga")
  end

  # Disables SendGrid click tracking for authentication emails
  # This ensures magic links and confirmation links work correctly
  defp maybe_disable_tracking(email, opts) do
    if Keyword.get(opts, :disable_tracking, false) do
      email
      |> put_provider_option(:click_tracking, %{enable: false})
      |> put_provider_option(:open_tracking, %{enable: false})
    else
      email
    end
  end

  @doc """
  Deliver instructions to update a user email.

  ## Options

    * `:from_email` - Email address to send from (default: configured or "noreply@jarga.app")
    * `:from_name` - Name to send from (default: configured or "Jarga")

  """
  @impl true
  def deliver_update_email_instructions(user, url, opts \\ []) do
    deliver(
      user.email,
      "Update email instructions",
      """

      ==============================

      Hi #{user.email},

      You can change your email by visiting the URL below:

      #{url}

      If you didn't request this change, please ignore this.

      ==============================
      """,
      Keyword.put(opts, :disable_tracking, true)
    )
  end

  @doc """
  Deliver instructions to log in with a magic link.

  ## Options

    * `:from_email` - Email address to send from (default: configured or "noreply@jarga.app")
    * `:from_name` - Name to send from (default: configured or "Jarga")

  """
  @impl true
  def deliver_login_instructions(user, url, opts \\ []) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url, opts)
      _ -> deliver_magic_link_instructions(user, url, opts)
    end
  end

  defp deliver_magic_link_instructions(user, url, opts) do
    deliver(
      user.email,
      "Log in instructions",
      """

      ==============================

      Hi #{user.email},

      You can log into your account by visiting the URL below:

      #{url}

      If you didn't request this email, please ignore this.

      ==============================
      """,
      Keyword.put(opts, :disable_tracking, true)
    )
  end

  defp deliver_confirmation_instructions(user, url, opts) do
    deliver(
      user.email,
      "Confirmation instructions",
      """

      ==============================

      Hi #{user.email},

      You can confirm your account by visiting the URL below:

      #{url}

      If you didn't create an account with us, please ignore this.

      ==============================
      """,
      Keyword.put(opts, :disable_tracking, true)
    )
  end

  @doc """
  Deliver instructions to reset password.

  ## Options

    * `:from_email` - Email address to send from (default: configured or "noreply@jarga.app")
    * `:from_name` - Name to send from (default: configured or "Jarga")

  """
  @impl true
  def deliver_reset_password_instructions(user, url, opts \\ []) do
    deliver(
      user.email,
      "Reset password instructions",
      """

      ==============================

      Hi #{user.email},

      You can reset your password by visiting the URL below:

      #{url}

      This link will expire in 1 hour.

      If you didn't request this password reset, please ignore this.

      ==============================
      """,
      Keyword.put(opts, :disable_tracking, true)
    )
  end
end
