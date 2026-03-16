defmodule Agents.Sessions.Application.UseCases.CompleteSession do
  @moduledoc """
  Use case for marking a session as completed.

  Called when the last task in a session completes successfully.
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
        if SessionStateMachinePolicy.can_complete?(session.status) do
          session_repo.update_session(session, %{status: "completed"})
        else
          {:error, :invalid_transition}
        end
    end
  end
end
