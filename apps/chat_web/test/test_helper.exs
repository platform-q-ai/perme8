ExUnit.start(capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Chat.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Agents.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Notifications.Repo, :manual)
