# Start Wallaby for ExUnit browser tests (gfm_checkbox, undo_redo, etc.)
# BDD features are now run externally via exo-bdd (mix exo_test --app jarga_web)
{:ok, _} = Application.ensure_all_started(:wallaby)
Application.put_env(:wallaby, :base_url, JargaWeb.Endpoint.url())

# Exclude evaluation tests, browser-based tests, and WIP features by default
ExUnit.start(exclude: [:evaluation, :javascript, :wip], capture_log: true)

Ecto.Adapters.SQL.Sandbox.mode(Jarga.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Identity.Repo, :manual)

# Mocks are defined in apps/jarga/test/test_helper.exs to avoid redefinition warnings
