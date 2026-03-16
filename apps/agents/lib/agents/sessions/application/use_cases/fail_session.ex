defmodule Agents.Sessions.Application.UseCases.FailSession do
  @moduledoc """
  Use case for marking a session as failed.

  Called when a task fails and the session should be marked as failed.
  """

  alias Agents.Sessions.Domain.Policies.SessionStateMachinePolicy

  @default_session_repo Agents.Sessions.Infrastructure.Repositories.SessionRepository

  @spec execute(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(session_id, opts \\ []) do
    session_repo = Keyword.get(opts, :session_repo, @default_session_repo)

    case session_repo.get_session(session_id) do
      nil ->
        {:error, :not_found}

      session ->
        if SessionStateMachinePolicy.can_fail?(session.status) do
          session_repo.update_session(session, %{status: "failed"})
        else
          {:error, :invalid_transition}
        end
    end
  end
end
