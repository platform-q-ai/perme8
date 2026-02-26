ExUnit.start(capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Notifications.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)

Mox.defmock(Notifications.Mocks.NotificationRepositoryMock,
  for: Notifications.Application.Behaviours.NotificationRepositoryBehaviour
)
