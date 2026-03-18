defmodule Agents.Sessions.Application.UseCases.FailSession do
  @moduledoc """
  Use case for marking a session as failed.

  Called when a task fails and the session should be marked as failed.
  Delegates session fetch and state-machine validation to `SessionTransition`.
  """

  alias Agents.Sessions.Application.SessionTransition

  @default_session_repo Agents.Sessions.Infrastructure.Repositories.SessionRepository

  @spec execute(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(session_id, opts \\ []) do
    SessionTransition.with_session_transition(
      session_id,
      "failed",
      fn session ->
        session_repo = Keyword.get(opts, :session_repo, @default_session_repo)
        session_repo.update_session(session, %{status: "failed"})
      end,
      opts
    )
  end
end
