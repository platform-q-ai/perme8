defmodule Jarga.Accounts.Application.UseCases.DeliverLoginInstructions do
  @moduledoc """
  Use case for delivering login instructions via magic link.

  ## Business Rules

  - Generates a token with context "login"
  - Token is persisted in database before email is sent
  - Email contains a URL with the encoded token for magic link login
  - Uses UserNotifier to deliver the email

  ## Dependency Injection

  This use case accepts the following dependencies via opts:
  - `:repo` - Ecto.Repo module (default: Jarga.Repo)
  - `:user_token_repo` - UserTokenRepository module (default: Infrastructure.Repositories.UserTokenRepository)
  - `:notifier` - Notifier function (default: UserNotifier.deliver_login_instructions/2)

  ## Responsibilities

  - Build email token with context "login"
  - Persist token in database
  - Generate login URL using provided function
  - Deliver email with magic link to user
  """

  @behaviour Jarga.Accounts.Application.UseCases.UseCase

  alias Jarga.Accounts.Domain.Services.TokenBuilder

  # Default implementations - can be overridden via opts for testing
  @default_repo Jarga.Repo
  @default_user_token_repo Jarga.Accounts.Infrastructure.Repositories.UserTokenRepository
  @default_notifier Jarga.Accounts.Infrastructure.Notifiers.UserNotifier

  @doc """
  Executes the deliver login instructions use case.

  ## Parameters

  - `params` - Map containing:
    - `:user` - The user requesting login
    - `:url_fun` - Function that takes encoded token and returns magic link URL

  - `opts` - Keyword list of options:
    - `:repo` - Repository module (default: Jarga.Repo)
    - `:user_token_repo` - UserTokenRepository module (default: Infrastructure.Repositories.UserTokenRepository)
    - `:notifier` - Notifier function (default: UserNotifier.deliver_login_instructions/2)

  ## Returns

  - Result from the notifier (typically `{:ok, email}`)
  """
  @impl true
  def execute(params, opts \\ []) do
    %{user: user, url_fun: url_fun} = params

    repo = Keyword.get(opts, :repo, @default_repo)
    user_token_repo = Keyword.get(opts, :user_token_repo, @default_user_token_repo)
    notifier_module = Keyword.get(opts, :notifier_module, @default_notifier)

    notifier = Keyword.get(opts, :notifier, &notifier_module.deliver_login_instructions/2)

    # Build email token with context "login"
    {encoded_token, user_token} = TokenBuilder.build_email_token(user, "login")

    # Persist token in database
    user_token_repo.insert!(user_token, repo)

    # Generate login URL
    url = url_fun.(encoded_token)

    # Deliver email with magic link
    notifier.(user, url)
  end
end
