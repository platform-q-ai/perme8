import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

export default defineConfig({
  features: ['./features/**/*.feature'],
  servers: [
    {
      name: 'webhooks-api',
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
  // Map feature-file variable names to deterministic values from exo_seeds.exs.
  variables: {
    // --- API key tokens (must match plaintext tokens in exo_seeds.exs) ---
    'valid-admin-key-product-team': 'exo_test_doc_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'valid-member-key-product-team': 'exo_test_member_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'revoked-key-product-team': 'exo_test_revoked_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaa',

    // --- Seeded webhook subscription UUIDs ---
    'seeded-webhook-id': '11111111-1111-1111-1111-111111111101',
    'seeded-active-webhook-id': '11111111-1111-1111-1111-111111111102',
    'seeded-deactivated-webhook-id': '11111111-1111-1111-1111-111111111103',
    'seeded-deleted-webhook-id': '11111111-1111-1111-1111-111111111104',
    'seeded-webhook-with-deliveries-id': '11111111-1111-1111-1111-111111111105',
    'seeded-webhook-no-deliveries-id': '11111111-1111-1111-1111-111111111106',

    // --- Seeded delivery UUIDs ---
    'seeded-success-delivery-id': '22222222-2222-2222-2222-222222222201',
    'seeded-failed-delivery-id': '22222222-2222-2222-2222-222222222202',
    'seeded-retried-delivery-id': '22222222-2222-2222-2222-222222222203',
    'seeded-pending-retry-delivery-id': '22222222-2222-2222-2222-222222222204',
    'seeded-retried-success-delivery-id': '22222222-2222-2222-2222-222222222205',
    'seeded-exhausted-delivery-id': '22222222-2222-2222-2222-222222222206',

    // --- Inbound webhook HMAC secret ---
    'inbound-webhook-secret-product-team': 'whsec_exo_test_inbound_secret_product_team_0001',

    // --- Pre-computed HMAC-SHA256 signatures for inbound webhook payloads ---
    // Computed as: sha256=hex(HMAC-SHA256(secret, body))
    // where secret = "whsec_exo_test_inbound_secret_product_team_0001"
    // and body = the exact docstring content from the feature file (Gherkin de-indented)
    'valid-inbound-signature': 'sha256=f44aedb40791ef46ca9d7fcf0fbae62968675782f74a0e5b6368b17c1a59057a',
    'valid-inbound-signature-routable': 'sha256=9cd05f54d087b02eae20737f820c2e2b7c5b50bcd60bfa0bf0da4461f83191f0',
    'valid-inbound-signature-malformed': 'sha256=62a12e0918ff50763f74b75c063fa0dd93e65724276b1695973f8428135cf077',
    'valid-inbound-signature-audit': 'sha256=9d57d1bcdae33279cbcf05503f318fb789fd838f7b5abc7639c8ba942660b2c1',
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
