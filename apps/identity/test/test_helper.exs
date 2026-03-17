# Exclude evaluation tests and browser-based tests by default
ExUnit.start(exclude: [:evaluation, :javascript], capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)
