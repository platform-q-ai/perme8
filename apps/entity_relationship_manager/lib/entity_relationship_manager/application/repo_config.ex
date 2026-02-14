defmodule EntityRelationshipManager.Application.RepoConfig do
  @moduledoc """
  Runtime repository configuration.

  Resolves which `SchemaRepositoryBehaviour` and `GraphRepositoryBehaviour`
  implementations to use. Uses `Application.get_env/3` for runtime
  resolution so that integration/BDD tests (which hit the live HTTP server)
  can use real implementations while unit tests continue to use Mox mocks.

  Each use case should call these functions (or accept overrides via `opts`)
  rather than using `Application.compile_env` module attributes.
  """

  @default_schema_repo EntityRelationshipManager.Infrastructure.Repositories.SchemaRepository
  @default_graph_repo EntityRelationshipManager.Infrastructure.Repositories.GraphRepository

  @doc "Returns the configured schema repository module."
  def schema_repo do
    Application.get_env(:entity_relationship_manager, :schema_repository, @default_schema_repo)
  end

  @doc "Returns the configured graph repository module."
  def graph_repo do
    Application.get_env(:entity_relationship_manager, :graph_repository, @default_graph_repo)
  end
end
