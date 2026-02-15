# Exclude evaluation tests, browser-based tests, and WIP features by default
# Browser BDD features are now run externally via exo-bdd (mix exo_test --app jarga_web)
ExUnit.start(exclude: [:evaluation, :javascript, :wip], capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)

# Mocks are defined in apps/jarga/test/test_helper.exs to avoid redefinition warnings
