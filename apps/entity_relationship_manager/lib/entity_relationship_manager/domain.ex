defmodule EntityRelationshipManager.Domain do
  @moduledoc """
  Domain layer boundary for the Entity Relationship Manager.

  The domain layer is the innermost layer with NO external dependencies.
  It contains:

  - **Entities** - Core business objects (Entity, Edge, SchemaDefinition, etc.)
  - **Policies** - Business rules (schema validation, input sanitization, authorization, traversal)
  - **Domain Services** - Pure functions for domain logic (PropertyValidator)
  """

  use Boundary,
    deps: [],
    exports: [
      {Entities.SchemaDefinition, []},
      {Entities.EntityTypeDefinition, []},
      {Entities.EdgeTypeDefinition, []},
      {Entities.PropertyDefinition, []},
      {Entities.Entity, []},
      {Entities.Edge, []},
      {Policies.SchemaValidationPolicy, []},
      {Policies.InputSanitizationPolicy, []},
      {Policies.TraversalPolicy, []},
      {Policies.AuthorizationPolicy, []},
      {Services.PropertyValidator, []}
    ]
end
