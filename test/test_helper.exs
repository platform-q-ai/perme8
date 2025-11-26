# Start Wallaby for E2E browser tests
# Always start Wallaby, but tests are excluded by default via :javascript tag
{:ok, _} = Application.ensure_all_started(:wallaby)
Application.put_env(:wallaby, :base_url, JargaWeb.Endpoint.url())

# Compile Cucumber features and step definitions
# Cucumber will auto-discover features and steps based on config in test.exs
Cucumber.compile_features!()

# Exclude evaluation tests and browser-based tests by default
# All browser tests (both Cucumber features and ExUnit tests) use @javascript tag
# To run browser tests: mix test --include javascript
# To run evaluation tests: mix test --include evaluation
# Capture log output to suppress expected error messages in tests
ExUnit.start(exclude: [:evaluation, :javascript], capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)

# Note: Test users are created in FeatureCase setup, not here
# This is because we need proper database sandbox setup first

# Define mocks for testing
Mox.defmock(Jarga.Agents.Application.Services.LlmClientMock,
  for: Jarga.Agents.Infrastructure.Services.Behaviours.LlmClientBehaviour
)
