import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

export default defineConfig({
  features: ['./features/**/*.feature'],
  servers: [
    {
      name: 'agents-api',
      command: 'mix phx.server',
      port: 4009,
      workingDir: '../../../',
      env: { MIX_ENV: 'test' },
      seed: 'mix run --no-start apps/jarga/priv/repo/exo_seeds.exs',
      healthCheckPath: '/api/health',
      startTimeout: 60000,
    },
  ],
  timeout: 300_000,
  // Map feature-file variable names to deterministic API key tokens.
  // These must match the plaintext tokens in apps/jarga/priv/repo/exo_seeds.exs.
  variables: {
    'valid-doc-key-product-team': 'exo_test_doc_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'revoked-key-product-team': 'exo_test_revoked_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'valid-no-access-key': 'exo_test_no_access_key_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  },
  adapters: {
    http: {
      baseURL: 'http://localhost:4009',
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
