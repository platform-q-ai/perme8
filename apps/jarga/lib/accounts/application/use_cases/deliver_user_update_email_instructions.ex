defmodule Jarga.Accounts.Application.UseCases.DeliverUserUpdateEmailInstructions do
  @moduledoc """
  Use case for delivering user email update instructions.

  ## Business Rules

  - Generates a token with context "change:<current_email>"
  - Token context includes the current email to validate the change request
  - Token is persisted in database before email is sent
  - Email contains a URL with the encoded token for verification
  - Uses UserNotifier to deliver the email

  ## Responsibilities

  - Build email token with proper context format (change:<email>)
  - Persist token in database
  - Generate confirmation URL using provided function
  - Deliver email with instructions to user
  """

  @behaviour Jarga.Accounts.Application.UseCases.UseCase

  alias Jarga.Accounts.Domain.Services.TokenBuilder
  alias Jarga.Accounts.Infrastructure.Notifiers.UserNotifier
  alias Jarga.Accounts.Infrastructure.Repositories.UserTokenRepository

  @doc """
  Executes the deliver user update email instructions use case.

  ## Parameters

  - `params` - Map containing:
    - `:user` - The user updating their email
    - `:current_email` - The current email address (for token context)
    - `:url_fun` - Function that takes encoded token and returns confirmation URL

  - `opts` - Keyword list of options:
    - `:repo` - Repository module (default: Jarga.Repo)
    - `:notifier` - Notifier function (default: UserNotifier.deliver_update_email_instructions/2)

  ## Returns

  - Result from the notifier (typically `{:ok, email}`)
  """
  @impl true
  def execute(params, opts \\ []) do
    %{user: user, current_email: current_email, url_fun: url_fun} = params

    repo = Keyword.get(opts, :repo, Jarga.Repo)
    notifier = Keyword.get(opts, :notifier, &UserNotifier.deliver_update_email_instructions/2)

    # Build email token with context "change:current_email"
    context = "change:#{current_email}"
    {encoded_token, user_token} = TokenBuilder.build_email_token(user, context)

    # Persist token in database
    UserTokenRepository.insert!(user_token, repo)

    # Generate confirmation URL
    url = url_fun.(encoded_token)

    # Deliver email with instructions
    notifier.(user, url)
  end
end
