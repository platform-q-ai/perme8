defmodule Agents.Sessions.Application.SessionTransition do
  @moduledoc """
  Shared helper that encapsulates the fetch-check-update pattern
  common to session lifecycle use cases.

  Fetches a session, validates that the requested status transition is
  allowed by `SessionStateMachinePolicy`, and either returns the session
  or invokes an optional callback with it.

  Two public functions correspond to two fetch modes:

  - `with_session_transition/3` -- **Unscoped** fetch via `get_session/1`.
    Used by `CompleteSession` and `FailSession`.
  - `with_user_session_transition/4` -- **User-scoped** fetch via
    `get_session_for_user/2`. Used by `PauseSession` and `ResumeSession`.

  ## Callback contract

  The optional `fun` callback receives the fetched session (a map) after
  the transition has been validated. It must return `{:ok, result}` or
  `{:error, reason}`. If no callback is provided, `{:ok, session}` is
  returned by default.
  """

  alias Agents.Sessions.Domain.Policies.SessionStateMachinePolicy

  @default_session_repo Agents.Sessions.Infrastructure.Repositories.SessionRepository

  @type session_id :: String.t()
  @type user_id :: String.t()
  @type target_status :: String.t()
  @type transition_callback :: (map() -> {:ok, map()} | {:error, term()})

  # ── Unscoped (no user filtering) ──────────────────────────────────

  @doc """
  Fetches a session (unscoped), validates the transition, and returns
  `{:ok, session}` or invokes `fun` with the session.

  ## Options

  - `:session_repo` -- override the default session repository (useful for tests).
  """
  @spec with_session_transition(session_id, target_status, transition_callback, keyword()) ::
          {:ok, map()} | {:error, term()}
  def with_session_transition(session_id, target_status, fun \\ &default_callback/1, opts \\ []) do
    session_repo = Keyword.get(opts, :session_repo, @default_session_repo)

    session_repo.get_session(session_id)
    |> do_transition(target_status, fun)
  end

  # ── User-scoped ───────────────────────────────────────────────────

  @doc """
  Fetches a user-scoped session, validates the transition, and returns
  `{:ok, session}` or invokes `fun` with the session.

  Uses `get_session_for_user/2` to ensure the session belongs to the
  given user, returning `{:error, :not_found}` if it does not.

  ## Options

  - `:session_repo` -- override the default session repository (useful for tests).
  """
  @spec with_user_session_transition(
          session_id,
          user_id,
          target_status,
          transition_callback,
          keyword()
        ) :: {:ok, map()} | {:error, term()}
  def with_user_session_transition(
        session_id,
        user_id,
        target_status,
        fun \\ &default_callback/1,
        opts \\ []
      ) do
    session_repo = Keyword.get(opts, :session_repo, @default_session_repo)

    session_repo.get_session_for_user(session_id, user_id)
    |> do_transition(target_status, fun)
  end

  # ── Private ───────────────────────────────────────────────────────

  defp do_transition(nil, _target_status, _fun), do: {:error, :not_found}

  defp do_transition(session, target_status, fun) do
    if SessionStateMachinePolicy.can_transition?(session.status, target_status) do
      fun.(session)
    else
      {:error, :invalid_transition}
    end
  end

  defp default_callback(session), do: {:ok, session}
end
