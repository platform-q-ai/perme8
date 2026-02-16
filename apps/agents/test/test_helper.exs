ExUnit.start(capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)

# Define mocks for testing
Mox.defmock(Agents.Infrastructure.Services.LlmClientMock,
  for: Agents.Application.Behaviours.LlmClientBehaviour
)
