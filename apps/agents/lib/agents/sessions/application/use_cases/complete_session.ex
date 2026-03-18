defmodule Agents.Sessions.Application.UseCases.CompleteSession do
  @moduledoc """
  Use case for marking a session as completed.

  Called when the last task in a session completes successfully.
  Delegates session fetch and state-machine validation to `SessionTransition`.
  """

  alias Agents.Sessions.Application.SessionTransition

  @default_session_repo Agents.Sessions.Infrastructure.Repositories.SessionRepository

  @spec execute(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(session_id, opts \\ []) do
    SessionTransition.with_session_transition(
      session_id,
      "completed",
      fn session ->
        session_repo = Keyword.get(opts, :session_repo, @default_session_repo)
        session_repo.update_session(session, %{status: "completed"})
      end,
      opts
    )
  end
end
