# Exclude WIP features by default
# BDD features are run externally via exo-bdd (mix exo_test --app jarga_api)
ExUnit.start(exclude: [:wip], capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)
