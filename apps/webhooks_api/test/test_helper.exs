ExUnit.start(capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Webhooks.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)
