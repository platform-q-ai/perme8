ExUnit.start(capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)

# Define mocks for testing
Mox.defmock(Agents.Infrastructure.Services.LlmClientMock,
  for: Agents.Application.Behaviours.LlmClientBehaviour
)

# Knowledge MCP mocks
Mox.defmock(Agents.Mocks.ErmGatewayMock,
  for: Agents.Application.Behaviours.ErmGatewayBehaviour
)

Mox.defmock(Agents.Mocks.IdentityMock,
  for: Agents.Application.Behaviours.IdentityBehaviour
)
