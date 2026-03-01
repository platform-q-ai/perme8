ExUnit.start(capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Chat.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)
