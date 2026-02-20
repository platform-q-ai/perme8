import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

export default defineConfig({
  features: [
    './features/**/*.http.feature',
    './features/**/*.security.feature',
  ],
  servers: [
    {
      name: 'entity-relationship-manager',
      command: 'mix phx.server',
      port: 4006,
      workingDir: '../../../',
      env: { MIX_ENV: 'test', ERM_REAL_REPOS: 'true' },
      seed: 'mix run --no-start apps/jarga/priv/repo/exo_seeds.exs',
      healthCheckPath: '/health',
      startTimeout: 30000,
    },
  ],
  timeout: 300_000,
  tags: 'not @neo4j',
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
    'valid-read-key-product-team': 'exo_test_read_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    // alice (engineering only - NOT a member of product-team via this key)
    'valid-key-engineering-only': 'exo_test_eng_key_only_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    // alice (revoked key)
    'revoked-key-product-team': 'exo_test_revoked_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    // bob (member of product-team)
    'valid-member-key-product-team': 'exo_test_member_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    // guest (guest of product-team)
    'valid-guest-key-product-team': 'exo_test_guest_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    // alice (multi-workspace: product-team + engineering)
    'valid-multi-workspace-key': 'exo_test_multi_workspace_key_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    // alice (no workspace access at all)
    'valid-no-access-key': 'exo_test_no_access_key_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    // alice (product-team + ghost-workspace that doesn't exist)
    'valid-phantom-workspace-key': 'exo_test_phantom_workspace_key_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  },
  report: { allure: true },
  adapters: {
    http: {
      baseURL: 'http://localhost:4006',
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
