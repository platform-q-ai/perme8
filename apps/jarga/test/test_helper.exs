# Exclude evaluation tests and WIP features by default
ExUnit.start(exclude: [:evaluation, :wip], capture_log: true)

# Both repos need manual mode so DataCase can checkout each test's connection.
# Jarga.Repo is also checked out for spawned processes (LiveView channels)
# that call it directly without the dynamic repo override.
Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Agents.Repo, :manual)

# Agents mocks are defined in apps/agents/test/test_helper.exs
