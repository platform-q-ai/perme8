import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

export default defineConfig({
  features: [
    './features/**/*.http.feature',
    './features/**/*.security.feature',
  ],
  servers: [
    {
      name: 'agents-mcp',
      command: 'mix phx.server',
      port: 4007,
      workingDir: '../../../',
      env: { MIX_ENV: 'test', ERM_REAL_REPOS: 'true' },
      seed: 'mix run --no-start apps/jarga/priv/repo/exo_seeds.exs',
      healthCheckPath: '/health',
      startTimeout: 30000,
    },
  ],
  timeout: 300_000,
  // Map feature-file variable names to values from the seed data.
  // Tokens must match the plaintext tokens in apps/jarga/priv/repo/exo_seeds.exs.
  // Workspace IDs must match the deterministic UUIDs defined in that seed file.
  variables: {
    // --- Workspace UUIDs (deterministic, set in exo_seeds.exs) ---
    'workspace-id-product-team': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeee01',
    'workspace-id-engineering': 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeee02',

    // --- API key tokens by role ---
    // alice (owner of product-team and engineering)
    'valid-doc-key-product-team': 'exo_test_doc_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    // alice (revoked key)
    'revoked-key-product-team': 'exo_test_revoked_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    // alice (no workspace access at all)
    'valid-no-access-key': 'exo_test_no_access_key_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  },
  report: { allure: true },
  adapters: {
    http: {
      baseURL: 'http://localhost:4007',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/event-stream',
      },
    },
    security: {
      zapUrl: 'http://localhost:8080',
      docker: {
        image: 'ghcr.io/zaproxy/zaproxy:stable',
        name: 'exo-bdd-zap',
        network: 'host',
      },
    },
  },
})
