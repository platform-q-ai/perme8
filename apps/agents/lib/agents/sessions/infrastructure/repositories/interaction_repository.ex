defmodule Agents.Sessions.Infrastructure.Repositories.InteractionRepository do
  @moduledoc """
  Repository for managing session interactions.
  """

  alias Agents.Repo
  alias Agents.Sessions.Infrastructure.Schemas.InteractionSchema
  alias Agents.Sessions.Infrastructure.Queries.InteractionQueries

  def create_interaction(attrs) do
    %InteractionSchema{}
    |> InteractionSchema.changeset(attrs)
    |> Repo.insert()
  end

  def list_for_session(session_id, _opts \\ []) do
    InteractionQueries.base()
    |> InteractionQueries.for_session(session_id)
    |> InteractionQueries.chronological()
    |> Repo.all()
  end

  def get_pending_question(session_id) do
    InteractionQueries.latest_pending_question(session_id)
    |> Repo.one()
  end

  def update_status(%InteractionSchema{} = interaction, attrs) do
    interaction
    |> InteractionSchema.status_changeset(attrs)
    |> Repo.update()
  end

  def delete_for_session(session_id) do
    InteractionQueries.base()
    |> InteractionQueries.for_session(session_id)
    |> Repo.delete_all()
  end

  def get_by_correlation_id(session_id, correlation_id) do
    InteractionQueries.base()
    |> InteractionQueries.for_session(session_id)
    |> InteractionQueries.by_correlation_id(correlation_id)
    |> Repo.one()
  end
end
