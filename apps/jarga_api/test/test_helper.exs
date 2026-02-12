# Exclude WIP features by default
ExUnit.start(exclude: [:wip], capture_log: true)

# Compile Cucumber features and step definitions
Cucumber.compile_features!()

Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)
