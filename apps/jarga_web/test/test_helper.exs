# Exclude evaluation tests by default
# Browser tests are run externally via exo-bdd (mix exo_test --name jarga-web)
ExUnit.start(exclude: [:evaluation], capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Agents.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Notifications.Repo, :manual)

# Mocks are defined in apps/jarga/test/test_helper.exs to avoid redefinition warnings
