defmodule Identity.Infrastructure.Notifiers.WorkspaceNotifier do
  @moduledoc """
  Notifier for workspace-related emails.
  """

  @behaviour Identity.Application.Behaviours.WorkspaceNotifierBehaviour

  import Swoosh.Email

  alias Identity.Domain.Entities.User
  alias Identity.Mailer
  alias Identity.Domain.Entities.Workspace

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({app_name(), default_from_email()})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver workspace invitation email to a new user.
  """
  def deliver_invitation_to_new_user(
        email,
        %Workspace{} = workspace,
        %User{} = inviter,
        signup_url
      ) do
    deliver(email, "You've been invited to #{workspace.name} on #{app_name()}", """

    ==============================

    Hi,

    #{inviter.first_name} #{inviter.last_name} has invited you to join the workspace "#{workspace.name}" on #{app_name()}.

    To accept this invitation, you'll need to create a #{app_name()} account first. Sign up here:

    #{signup_url}

    After you create your account and confirm your email, you'll automatically be added to the workspace "#{workspace.name}".

    ==============================
    """)
  end

  @doc """
  Deliver workspace invitation notification to an existing user.
  """
  def deliver_invitation_to_existing_user(
        %User{} = user,
        %Workspace{} = workspace,
        %User{} = inviter,
        workspace_url
      ) do
    deliver(user.email, "You've been invited to #{workspace.name}", """

    ==============================

    Hi #{user.first_name},

    #{inviter.first_name} #{inviter.last_name} has invited you to join the workspace "#{workspace.name}".

    You've been automatically added to the workspace. Visit it here:

    #{workspace_url}

    ==============================
    """)
  end

  @doc """
  Sends an invitation email to an existing user, building the workspace URL automatically.
  """
  @impl true
  def notify_existing_user(%User{} = user, %Workspace{} = workspace, %User{} = inviter) do
    workspace_url = build_workspace_url(workspace.id)
    deliver_invitation_to_existing_user(user, workspace, inviter, workspace_url)
  end

  @doc """
  Sends an invitation email to a new user, building the signup URL automatically.
  """
  @impl true
  def notify_new_user(email, %Workspace{} = workspace, %User{} = inviter) do
    signup_url = build_signup_url()
    deliver_invitation_to_new_user(email, workspace, inviter, signup_url)
  end

  defp app_name, do: Application.get_env(:identity, :app_name, "Perme8")

  defp default_from_email,
    do: Application.get_env(:identity, :mailer_from_email, "noreply@perme8.app")

  defp base_url, do: Application.get_env(:identity, :base_url, "http://localhost:4000")

  defp build_workspace_url(workspace_id) do
    "#{base_url()}/app/workspaces/#{workspace_id}"
  end

  defp build_signup_url do
    "#{base_url()}/users/register"
  end
end
