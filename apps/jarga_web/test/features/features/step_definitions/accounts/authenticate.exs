defmodule Accounts.AuthenticateSteps do
  @moduledoc """
  Step definitions for user authentication scenarios (magic link, password, session).
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Jarga.AccountsFixtures
  import Ecto.Query

  alias Jarga.Accounts
  alias Jarga.Accounts.Infrastructure.Schemas.UserTokenSchema
  alias Jarga.Repo

  # ============================================================================
  # MAGIC LINK TOKENS
  # ============================================================================

  step "a magic link token is generated for {string}", %{args: [email]} = context do
    user = context[:user] || Accounts.get_user_by_email(email)
    {encoded_token, _token} = generate_user_magic_link_token(user)
    {:ok, Map.put(context, :magic_link_token, encoded_token) |> Map.put(:user, user)}
  end

  step "an expired magic link token exists for {string}", %{args: [email]} = context do
    user = context[:user] || Accounts.get_user_by_email(email)
    {encoded_token, token} = generate_user_magic_link_token(user)

    # Expire the token by setting inserted_at to 20 minutes ago
    offset_user_token(token, -21, :minute)

    {:ok, Map.put(context, :expired_token, encoded_token) |> Map.put(:user, user)}
  end

  step "I login with the magic link token", context do
    token = context[:magic_link_token]
    result = Accounts.login_user_by_magic_link(token)

    case result do
      {:ok, {user, expired_tokens}} ->
        Map.put(context, :user, user)
        |> Map.put(:expired_tokens, expired_tokens)
        |> Map.put(:login_result, :ok)

      {:error, reason} ->
        Map.put(context, :login_result, {:error, reason})
    end
  end

  step "I attempt to login with an invalid magic link token", context do
    result = Accounts.login_user_by_magic_link("invalid_token")

    case result do
      {:error, reason} ->
        Map.put(context, :login_result, {:error, reason})

      {:ok, _} ->
        Map.put(context, :login_result, :ok)
    end
  end

  step "I attempt to login with the expired token", context do
    token = context[:expired_token]
    result = Accounts.login_user_by_magic_link(token)

    case result do
      {:error, reason} ->
        Map.put(context, :login_result, {:error, reason})

      {:ok, _} ->
        Map.put(context, :login_result, :ok)
    end
  end

  # ============================================================================
  # PASSWORD AUTHENTICATION
  # ============================================================================

  step "I login with email {string} and password {string}",
       %{args: [email, password]} = context do
    user = Accounts.get_user_by_email_and_password(email, password)

    {:ok,
     Map.put(context, :login_user, user)
     |> Map.put(:login_result, if(user, do: :ok, else: {:error, :invalid_credentials}))}
  end

  step "I attempt to login with email {string} and password {string}",
       %{args: [email, password]} = context do
    user = Accounts.get_user_by_email_and_password(email, password)

    {:ok,
     Map.put(context, :login_user, user)
     |> Map.put(:login_result, if(user, do: :ok, else: {:error, :invalid_credentials}))}
  end

  # ============================================================================
  # SESSION TOKENS
  # ============================================================================

  step "I generate a session token for the user", context do
    user = context[:user]
    token = Accounts.generate_user_session_token(user)
    {:ok, Map.put(context, :session_token, token)}
  end

  step "a valid session token exists for the user", context do
    user = context[:user]
    token = Accounts.generate_user_session_token(user)
    {:ok, Map.put(context, :session_token, token)}
  end

  step "a session token was created 90 days ago", context do
    user = context[:user]
    token = Accounts.generate_user_session_token(user)

    # Get the raw token from database and update its inserted_at
    token_record = Repo.get_by(UserTokenSchema, token: token, context: "session")
    offset_user_token(token_record.token, -91, :day)

    {:ok, Map.put(context, :old_session_token, token)}
  end

  step "I retrieve the user by session token", context do
    token = context[:session_token]
    result = Accounts.get_user_by_session_token(token)

    case result do
      {user, inserted_at} ->
        Map.put(context, :retrieved_user, user) |> Map.put(:token_inserted_at, inserted_at)

      nil ->
        Map.put(context, :retrieved_user, nil)
    end
  end

  step "I attempt to retrieve a user with an invalid session token", context do
    result = Accounts.get_user_by_session_token("invalid_token")
    {:ok, Map.put(context, :retrieved_user, result)}
  end

  step "I attempt to retrieve the user by that session token", context do
    token = context[:old_session_token]
    result = Accounts.get_user_by_session_token(token)
    {:ok, Map.put(context, :retrieved_user, result)}
  end

  step "I attempt to retrieve the user by session token using the magic link token", context do
    token = context[:magic_link_token]
    result = Accounts.get_user_by_session_token(token)
    {:ok, Map.put(context, :retrieved_user, result)}
  end

  step "I delete the session token", context do
    token = context[:session_token]
    result = Accounts.delete_user_session_token(token)
    {:ok, Map.put(context, :delete_result, result)}
  end

  # ============================================================================
  # SUDO MODE
  # ============================================================================

  step "the user authenticated {int} minutes ago", %{args: [minutes]} = context do
    user = context[:user]
    authenticated_at = DateTime.add(DateTime.utc_now(), -minutes * 60, :second)

    # Update user's authenticated_at field via token
    # Create a session token and override its authenticated_at
    token = Accounts.generate_user_session_token(user)
    override_token_authenticated_at(token, authenticated_at)

    # Retrieve user with token to get authenticated_at
    {user_with_auth, _} = Accounts.get_user_by_session_token(token)

    {:ok, Map.put(context, :user, user_with_auth) |> Map.put(:session_token, token)}
  end

  step "the user has no authenticated_at timestamp", context do
    # User without session token has no authenticated_at
    # The authenticated_at field is virtual and only set when retrieved via session token
    # So we just ensure the user doesn't have any session tokens that would set it
    user = context[:user]

    # Make sure user has no session tokens
    session_tokens =
      Repo.all(
        from(t in UserTokenSchema, where: t.user_id == ^user.id and t.context == "session")
      )

    assert Enum.empty?(session_tokens)

    # When we check sudo mode, the user will have nil authenticated_at
    {:ok, context}
  end

  step "I check if the user is in sudo mode", context do
    user = context[:user]
    result = Accounts.sudo_mode?(user)
    {:ok, Map.put(context, :sudo_mode_result, result)}
  end

  step "I check if the user is in sudo mode with a {int} minute limit",
       %{args: [minutes]} = context do
    user = context[:user]
    result = Accounts.sudo_mode?(user, -minutes)
    {:ok, Map.put(context, :sudo_mode_result, result)}
  end
end
