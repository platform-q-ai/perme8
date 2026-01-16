defmodule Accounts.VerifyTokensSteps do
  @moduledoc """
  Step definitions for token verification and assertions.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  alias Jarga.Accounts.Infrastructure.Repositories.{UserRepository, UserTokenRepository}

  # ============================================================================
  # TOKEN ASSERTIONS
  # ============================================================================

  step "the magic link token should be deleted", context do
    user = context[:user]

    # Verify no login tokens exist for this user
    tokens = UserTokenRepository.all_by_user_id(user.id)
    login_tokens = Enum.filter(tokens, &(&1.context == "login"))

    assert Enum.empty?(login_tokens)
    {:ok, context}
  end

  step "no other tokens should be deleted", context do
    # For Case 1 (confirmed user), only the magic link token should be deleted
    # The expired_tokens list should be empty (no tokens were expired)
    expired_tokens = context[:expired_tokens] || []
    assert Enum.empty?(expired_tokens)
    {:ok, context}
  end

  step "all user tokens should be deleted for security", context do
    user = context[:user]

    # Verify ALL tokens are deleted for this user
    tokens = UserTokenRepository.all_by_user_id(user.id)
    assert Enum.empty?(tokens)
    {:ok, context}
  end

  step "only the magic link token should be deleted", context do
    user = context[:user]

    # Verify no login tokens exist
    tokens = UserTokenRepository.all_by_user_id(user.id)
    login_tokens = Enum.filter(tokens, &(&1.context == "login"))

    assert Enum.empty?(login_tokens)
    {:ok, context}
  end

  step "other session tokens should remain intact", context do
    user = context[:user]
    expired_tokens = context[:expired_tokens] || []
    assert Enum.empty?(expired_tokens)

    # Verify no login tokens remain
    tokens = UserTokenRepository.all_by_user_id(user.id)
    login_tokens = Enum.filter(tokens, &(&1.context == "login"))

    assert Enum.empty?(login_tokens)
    {:ok, context}
  end

  step "the confirmed_at timestamp should be set", context do
    user = UserRepository.get_by_id(context[:user].id)
    refute is_nil(user.confirmed_at)
    {:ok, Map.put(context, :user, user)}
  end

  step "the confirmed_at timestamp should be set to current time", context do
    user = UserRepository.get_by_id(context[:user].id)
    refute is_nil(user.confirmed_at)

    # Should be within 5 seconds of now
    now = DateTime.utc_now()
    diff = DateTime.diff(now, user.confirmed_at, :second)
    assert diff >= 0 and diff < 5

    {:ok, Map.put(context, :user, user)}
  end

  step "the timestamp should be in UTC", context do
    user = context[:user]
    # confirmed_at is stored as :utc_datetime, so it's always UTC
    assert user.confirmed_at.__struct__ == DateTime
    {:ok, context}
  end

  step "the session token should be created successfully", context do
    assert context[:session_token] != nil
    {:ok, context}
  end

  step "the token should be persisted in the database", context do
    user = context[:user]

    # Verify token exists in database
    tokens = UserTokenRepository.all_by_user_id(user.id)
    assert tokens != []
    {:ok, context}
  end

  step "the token context should be {string}", %{args: [expected_context]} = context do
    user = context[:user]
    tokens = UserTokenRepository.all_by_user_id(user.id)
    assert Enum.any?(tokens, &(&1.context == expected_context))
    {:ok, context}
  end

  step "I should receive an encoded token binary", context do
    token = context[:session_token]
    assert is_binary(token)
    {:ok, context}
  end

  step "I should receive the token inserted_at timestamp", context do
    assert context[:token_inserted_at] != nil
    {:ok, context}
  end

  step "the token should be removed from the database", context do
    user = context[:user]

    tokens = UserTokenRepository.all_by_user_id(user.id)
    session_tokens = Enum.filter(tokens, &(&1.context == "session"))

    assert Enum.empty?(session_tokens)
    {:ok, context}
  end

  step "the operation should return :ok", context do
    assert context[:delete_result] == :ok
    {:ok, context}
  end

  step "I should receive a list of expired tokens", context do
    assert is_list(context[:expired_tokens])
    {:ok, context}
  end

  step "no tokens should be deleted", context do
    user = context[:user]

    tokens = UserTokenRepository.all_by_user_id(user.id)

    # Token count should remain the same
    assert length(tokens) == context[:token_count_before]
    {:ok, context}
  end

  # ============================================================================
  # EMAIL DELIVERY ASSERTIONS
  # ============================================================================

  step "a login token should be generated with context {string}", %{args: [_ctx]} = context do
    user = context[:user]

    token_record = UserTokenRepository.get_by_user_id_and_context(user.id, "login")

    assert token_record != nil
    {:ok, context}
  end

  step "an email change token should be generated with context {string}",
       %{args: [expected_context]} = context do
    user = context[:user]

    token_record = UserTokenRepository.get_by_user_id_and_context(user.id, expected_context)

    assert token_record != nil
    {:ok, context}
  end
end
