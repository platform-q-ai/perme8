defmodule EntityRelationshipManager.Application do
  @moduledoc false

  use Application

  use Boundary,
    deps: [EntityRelationshipManager],
    exports: [
      {Behaviours.SchemaRepositoryBehaviour, []},
      {Behaviours.GraphRepositoryBehaviour, []}
    ]

  @impl true
  def start(_type, _args) do
    children = [
      EntityRelationshipManager.Endpoint
    ]

    opts = [strategy: :one_for_one, name: EntityRelationshipManager.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    EntityRelationshipManager.Endpoint.config_change(changed, removed)
    :ok
  end
end
