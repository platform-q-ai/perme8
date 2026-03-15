# Exclude evaluation tests and WIP features by default
ExUnit.start(exclude: [:evaluation, :wip], capture_log: true)

# Jarga.Repo uses put_dynamic_repo(Identity.Repo) in DataCase, so only
# Identity.Repo needs sandbox mode set here. Both share the same connection.
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Agents.Repo, :manual)

# Agents mocks are defined in apps/agents/test/test_helper.exs
