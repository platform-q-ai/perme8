# Exclude database-dependent and Neo4j integration tests by default
ExUnit.start(exclude: [:neo4j, :integration, :database], capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(EntityRelationshipManager.Repo, :manual)
