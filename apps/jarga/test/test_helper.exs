# Compile Cucumber features and step definitions
# Cucumber will auto-discover features and steps based on config in test.exs
# Since we moved features to jarga_web, this is now handled there.

# Exclude evaluation tests and WIP features by default
ExUnit.start(exclude: [:evaluation, :wip], capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)

# Define mocks for testing
Mox.defmock(Jarga.Agents.Infrastructure.Services.LlmClientMock,
  for: Jarga.Agents.Application.Behaviours.LlmClientBehaviour
)
