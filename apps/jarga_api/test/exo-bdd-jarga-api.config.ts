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
      // --no-start avoids booting Phoenix endpoints (ports already bound by the running server).
      // The seed script starts its own Ecto repo connections to the same Postgres database,
      // which is safe because Postgres handles concurrent connections from multiple OS processes.
      seed: 'mix run --no-start apps/jarga/priv/repo/exo_seeds.exs',
      healthCheckPath: '/api/workspaces',
      startTimeout: 30000,
    },
  ],
  // Active ZAP scans can take minutes; raise Cucumber step timeout accordingly.
  timeout: 300_000,
  // Map feature-file variable names to deterministic API key tokens.
  // These must match the plaintext tokens in apps/jarga/priv/repo/exo_seeds.exs.
  variables: {
    'valid-doc-key-product-team': 'exo_test_doc_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'valid-read-key-product-team': 'exo_test_read_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'valid-key-engineering-only': 'exo_test_eng_key_only_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'revoked-key-product-team': 'exo_test_revoked_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'valid-guest-key-product-team': 'exo_test_guest_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'valid-member-key-product-team': 'exo_test_member_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'valid-multi-workspace-key': 'exo_test_multi_workspace_key_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'valid-no-access-key': 'exo_test_no_access_key_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  },
  adapters: {
    http: {
      baseURL: 'http://localhost:4005',
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
