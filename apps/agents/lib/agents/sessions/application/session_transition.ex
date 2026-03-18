defmodule Agents.Sessions.Application.SessionTransition do
  @moduledoc """
  Shared helper that encapsulates the fetch-check-update pattern
  common to session lifecycle use cases.

  Fetches a session, validates that the requested status transition is
  allowed by `SessionStateMachinePolicy`, and either returns the session
  or invokes an optional callback with it.

  Supports two fetch modes:
  - **Unscoped** (`get_session/1`) -- used by CompleteSession, FailSession
  - **User-scoped** (`get_session_for_user/2`) -- used by PauseSession, ResumeSession
  """

  alias Agents.Sessions.Domain.Policies.SessionStateMachinePolicy

  @default_session_repo Agents.Sessions.Infrastructure.Repositories.SessionRepository

  @type session_id :: String.t()
  @type user_id :: String.t()
  @type target_status :: String.t()

  @doc """
  Fetches a session (unscoped), validates the transition, and returns `{:ok, session}`.
  """
  @spec with_session_transition(session_id, target_status) ::
          {:ok, map()} | {:error, :not_found | :invalid_transition}
  def with_session_transition(session_id, target_status) do
    with_session_transition(session_id, target_status, fn session -> {:ok, session} end, [])
  end

  @doc """
  Overloaded /3 variant.

  - When the third argument is a function, fetches unscoped and invokes the callback.
  - When the third argument is a keyword list, fetches unscoped with custom opts.
  - When the third argument is a binary (user_id), fetches user-scoped.
  """
  def with_session_transition(session_id, target_status, fun)
      when is_function(fun, 1) do
    with_session_transition(session_id, target_status, fun, [])
  end

  def with_session_transition(session_id, target_status, opts)
      when is_list(opts) do
    with_session_transition(session_id, target_status, fn session -> {:ok, session} end, opts)
  end

  def with_session_transition(session_id, user_id, target_status)
      when is_binary(user_id) and is_binary(target_status) do
    with_session_transition(
      session_id,
      user_id,
      target_status,
      fn session -> {:ok, session} end,
      []
    )
  end

  @doc """
  Overloaded /4 variant.

  - When the fourth argument is a function, fetches user-scoped and invokes the callback.
  - When the fourth argument is a keyword list, fetches user-scoped with custom opts.
  - When the second argument is a binary (target_status) and the third is a function,
    this is the unscoped variant with callback and opts.
  """
  def with_session_transition(session_id, user_id, target_status, fun)
      when is_binary(user_id) and is_binary(target_status) and is_function(fun, 1) do
    with_session_transition(session_id, user_id, target_status, fun, [])
  end

  def with_session_transition(session_id, user_id, target_status, opts)
      when is_binary(user_id) and is_binary(target_status) and is_list(opts) do
    with_session_transition(
      session_id,
      user_id,
      target_status,
      fn session -> {:ok, session} end,
      opts
    )
  end

  def with_session_transition(session_id, target_status, fun, opts)
      when is_binary(target_status) and is_function(fun, 1) and is_list(opts) do
    session_repo = Keyword.get(opts, :session_repo, @default_session_repo)

    case session_repo.get_session(session_id) do
      nil ->
        {:error, :not_found}

      session ->
        if SessionStateMachinePolicy.can_transition?(session.status, target_status) do
          fun.(session)
        else
          {:error, :invalid_transition}
        end
    end
  end

  @doc """
  Fetches a user-scoped session, validates the transition, and invokes the callback.

  This is the fully-expanded form with all parameters.
  """
  @spec with_session_transition(session_id, user_id, target_status, function(), keyword()) ::
          {:ok, map()} | {:error, :not_found | :invalid_transition}
  def with_session_transition(session_id, user_id, target_status, fun, opts)
      when is_binary(user_id) and is_binary(target_status) and is_function(fun, 1) and
             is_list(opts) do
    session_repo = Keyword.get(opts, :session_repo, @default_session_repo)

    case session_repo.get_session_for_user(session_id, user_id) do
      nil ->
        {:error, :not_found}

      session ->
        if SessionStateMachinePolicy.can_transition?(session.status, target_status) do
          fun.(session)
        else
          {:error, :invalid_transition}
        end
    end
  end
end
