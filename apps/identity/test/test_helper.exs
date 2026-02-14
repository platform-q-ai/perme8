# Exclude evaluation tests, browser-based tests, and WIP features by default
ExUnit.start(exclude: [:evaluation, :javascript, :wip], capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)
