ExUnit.start(capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Chat.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)

Mox.defmock(Chat.Mocks.SessionRepositoryMock,
  for: Chat.Application.Behaviours.SessionRepositoryBehaviour
)

Mox.defmock(Chat.Mocks.MessageRepositoryMock,
  for: Chat.Application.Behaviours.MessageRepositoryBehaviour
)
