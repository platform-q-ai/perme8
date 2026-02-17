# Exclude evaluation tests and WIP features by default
# Browser tests are run externally via exo-bdd (mix exo_test --name jarga-web)
ExUnit.start(exclude: [:evaluation, :wip], capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)

# Mocks are defined in apps/jarga/test/test_helper.exs to avoid redefinition warnings
