# Exclude evaluation tests by default
# To run evaluation tests: mix test --include evaluation
# Capture log output to suppress expected error messages in tests
ExUnit.start(exclude: [:evaluation], capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)
