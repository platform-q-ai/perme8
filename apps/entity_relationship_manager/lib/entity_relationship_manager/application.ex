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
  # requests without Mox expectations. The :real_repos flag is set in
  # config/runtime.exs from the ERM_REAL_REPOS environment variable.
  defp maybe_configure_real_repos do
    if Application.get_env(:entity_relationship_manager, :real_repos, false) do
      schema_repo = EntityRelationshipManager.Infrastructure.Repositories.SchemaRepository
      graph_repo = EntityRelationshipManager.Infrastructure.Repositories.InMemoryGraphRepository

      Application.put_env(:entity_relationship_manager, :schema_repository, schema_repo)
      Application.put_env(:entity_relationship_manager, :graph_repository, graph_repo)
      graph_repo.init!()
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    EntityRelationshipManager.Endpoint.config_change(changed, removed)
    :ok
  end
end
