import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

export default defineConfig({
  features: [
    './features/**/*.http.feature',
    './features/**/*.security.feature',
  ],
  servers: [
    {
      name: 'jarga-api',
      command: 'mix phx.server',
      port: 4005,
      workingDir: '../../../',
      env: { MIX_ENV: 'test' },
      seed: 'mix run --no-start apps/jarga/priv/repo/exo_seeds.exs',
      healthCheckPath: '/api/workspaces',
      startTimeout: 30000,
    },
  ],
  // Map feature-file variable names to deterministic API key tokens.
  // These must match the plaintext tokens in apps/jarga/priv/repo/exo_seeds.exs.
  variables: {
    'valid-doc-key-product-team': 'exo_test_doc_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'valid-read-key-product-team': 'exo_test_read_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'valid-key-engineering-only': 'exo_test_eng_key_only_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'revoked-key-product-team': 'exo_test_revoked_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'valid-guest-key-product-team': 'exo_test_guest_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'valid-member-key-product-team': 'exo_test_member_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  },
  adapters: {
    http: {
      baseURL: 'http://localhost:4005',
    },
    // security: {
    //   zapUrl: 'http://localhost:8080',
    // },
  },
})
