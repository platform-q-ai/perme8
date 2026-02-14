# Exclude WIP features, database-dependent, and Neo4j integration tests by default
ExUnit.start(exclude: [:wip, :neo4j, :integration, :database], capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)
