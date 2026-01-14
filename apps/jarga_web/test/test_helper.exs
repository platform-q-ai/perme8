# Start Wallaby for E2E browser tests
{:ok, _} = Application.ensure_all_started(:wallaby)
Application.put_env(:wallaby, :base_url, JargaWeb.Endpoint.url())

# Compile Cucumber features and step definitions
Cucumber.compile_features!()

# Exclude evaluation tests, browser-based tests, and WIP features by default
# All browser tests (both Cucumber features and ExUnit tests) use @javascript tag
ExUnit.start(exclude: [:evaluation, :javascript, :wip], capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)

# Define mocks for testing (shared with jarga)
Mox.defmock(Jarga.Agents.Infrastructure.Services.LlmClientMock,
  for: Jarga.Agents.Infrastructure.Services.Behaviours.LlmClientBehaviour
)
