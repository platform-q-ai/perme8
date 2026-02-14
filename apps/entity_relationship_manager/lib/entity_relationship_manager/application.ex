defmodule EntityRelationshipManager.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    maybe_configure_real_repos()

    children = [
      EntityRelationshipManager.Endpoint
    ]

    opts = [strategy: :one_for_one, name: EntityRelationshipManager.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # When ERM_REAL_REPOS=true (set by exo-bdd integration tests), switch from
  # Mox mocks to real implementations so the live HTTP server can handle
  # requests without Mox expectations.
  defp maybe_configure_real_repos do
    if System.get_env("ERM_REAL_REPOS") == "true" do
      Application.put_env(
        :entity_relationship_manager,
        :schema_repository,
        EntityRelationshipManager.Infrastructure.Repositories.SchemaRepository
      )

      Application.put_env(
        :entity_relationship_manager,
        :graph_repository,
        EntityRelationshipManager.Infrastructure.Repositories.InMemoryGraphRepository
      )

      # Initialize the in-memory graph repository ETS tables
      EntityRelationshipManager.Infrastructure.Repositories.InMemoryGraphRepository.init!()
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    EntityRelationshipManager.Endpoint.config_change(changed, removed)
    :ok
  end
end
