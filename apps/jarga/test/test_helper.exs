# Exclude evaluation tests by default
ExUnit.start(exclude: [:evaluation], capture_log: true)

# Jarga.Repo delegates to Identity.Repo via default_dynamic_repo in test mode,
# so only Identity.Repo needs sandbox mode set here.
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Agents.Repo, :manual)

# Agents mocks are defined in apps/agents/test/test_helper.exs
