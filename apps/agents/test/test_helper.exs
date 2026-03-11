ExUnit.start(capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Agents.Repo, :manual)
# Identity.Repo sandbox is needed because some Agents production code calls
# the Identity facade (e.g. Identity.get_user!/1) which uses Identity.Repo.
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

# Jarga MCP mocks
Mox.defmock(Agents.Mocks.JargaGatewayMock,
  for: Agents.Application.Behaviours.JargaGatewayBehaviour
)

# Sessions mocks
Mox.defmock(Agents.Mocks.ContainerProviderMock,
  for: Agents.Sessions.Application.Behaviours.ContainerProviderBehaviour
)

Mox.defmock(Agents.Mocks.OpencodeClientMock,
  for: Agents.Sessions.Application.Behaviours.OpencodeClientBehaviour
)

Mox.defmock(Agents.Mocks.TaskRepositoryMock,
  for: Agents.Sessions.Application.Behaviours.TaskRepositoryBehaviour
)

Mox.defmock(Agents.Mocks.GithubTicketClientMock,
  for: Agents.Application.Behaviours.GithubTicketClientBehaviour
)
