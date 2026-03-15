defmodule EntityRelationshipManager.Repo do
  @moduledoc """
  Ecto repository for the Entity Relationship Manager app.

  Connects to the same database as Jarga.Repo and Identity.Repo
  but allows the ERM bounded context to be self-contained
  without depending on other apps for persistence.
  """

  # Shared infrastructure - can be used by all EntityRelationshipManager modules
  use Boundary, top_level?: true, deps: []

  use Ecto.Repo,
    otp_app: :entity_relationship_manager,
    adapter: Ecto.Adapters.Postgres
end
