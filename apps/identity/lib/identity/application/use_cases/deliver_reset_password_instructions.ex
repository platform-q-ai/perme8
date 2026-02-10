defmodule Identity.Application.UseCases.DeliverResetPasswordInstructions do
  @moduledoc """
  Use case for delivering password reset instructions.

  ## Business Rules

  - Generates a token with context "reset_password"
  - Token is persisted in database before email is sent
  - Email contains a URL with the encoded token for password reset
  - Token is valid for 1 hour (see TokenPolicy.reset_password_validity_hours)
  - Uses UserNotifier to deliver the email

  ## Dependency Injection

  This use case accepts the following dependencies via opts:
  - `:repo` - Ecto.Repo module (default: Identity.Repo)
  - `:user_token_repo` - UserTokenRepository module (default: Infrastructure.Repositories.UserTokenRepository)
  - `:notifier` - Notifier function (default: UserNotifier.deliver_reset_password_instructions/2)

  ## Responsibilities

  - Build email token with context "reset_password"
  - Persist token in database
  - Generate reset URL using provided function
  - Deliver email with reset link to user
  """

  @behaviour Identity.Application.UseCases.UseCase

  alias Identity.Domain.Services.TokenBuilder

  # Default implementations - can be overridden via opts for testing
  @default_repo Identity.Repo
  @default_user_token_repo Identity.Infrastructure.Repositories.UserTokenRepository
  @default_notifier Identity.Infrastructure.Notifiers.UserNotifier

  @doc """
  Executes the deliver reset password instructions use case.

  ## Parameters

  - `params` - Map containing:
    - `:user` - The user requesting password reset
    - `:url_fun` - Function that takes encoded token and returns reset URL

  - `opts` - Keyword list of options:
    - `:repo` - Repository module (default: Identity.Repo)
    - `:user_token_repo` - UserTokenRepository module (default: Infrastructure.Repositories.UserTokenRepository)
    - `:notifier` - Notifier function (default: UserNotifier.deliver_reset_password_instructions/2)

  ## Returns

  - Result from the notifier (typically `{:ok, email}`)
  """
  @impl true
  def execute(params, opts \\ []) do
    %{user: user, url_fun: url_fun} = params

    repo = Keyword.get(opts, :repo, @default_repo)
    user_token_repo = Keyword.get(opts, :user_token_repo, @default_user_token_repo)
    notifier_module = Keyword.get(opts, :notifier_module, @default_notifier)

    notifier =
      Keyword.get(opts, :notifier, &notifier_module.deliver_reset_password_instructions/2)

    # Build email token with context "reset_password"
    {encoded_token, user_token} = TokenBuilder.build_email_token(user, "reset_password")

    # Persist token in database
    user_token_repo.insert!(user_token, repo)

    # Generate reset URL
    url = url_fun.(encoded_token)

    # Deliver email with reset link
    notifier.(user, url)
  end
end
