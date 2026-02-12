# Exclude WIP features by default
ExUnit.start(exclude: [:wip], capture_log: true)

# Compile Cucumber features and step definitions
# Exclude exo-bdd domain-specific features (*.http.feature, *.security.feature)
# which are run by the exo-bdd external test runner, not the Cucumber/ExUnit runner.
feature_files =
  Path.wildcard("test/features/**/*.feature")
  |> Enum.reject(&String.match?(&1, ~r/\.(http|security|browser|cli|graph)\.feature$/))

Cucumber.compile_features!(features: feature_files)

Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)
