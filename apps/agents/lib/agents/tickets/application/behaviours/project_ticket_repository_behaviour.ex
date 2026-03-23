defmodule Agents.Tickets.Application.Behaviours.ProjectTicketRepositoryBehaviour do
  @moduledoc "Behaviour for ticket persistence used by application-layer workflows."

  @callback get_by_number(integer()) :: {:ok, map()} | nil
  @callback unlink_session(integer()) :: {:ok, map()} | {:error, term()}
  @callback get_by_id(integer()) :: {:ok, map()} | nil
end
