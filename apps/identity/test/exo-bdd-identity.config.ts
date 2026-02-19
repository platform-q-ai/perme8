import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

export default defineConfig({
  features: [
    './features/**/*.browser.feature',
    './features/**/*.security.feature',
  ],
  variables: {
    resetToken: '7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u4',
    // Test user credentials (must match exo_seeds.exs)
    testEmail: 'alice@example.com',
    testPassword: 'SecurePassword123!',
  },
  servers: [
    {
      name: 'identity',
      command: 'mix phx.server',
      port: 4001,
      workingDir: '../../../',
      env: { MIX_ENV: 'test' },
      // --no-start avoids booting Phoenix endpoints (ports already bound by the running server).
      // The seed script starts its own Ecto repo connections to the same Postgres database,
      // which is safe because Postgres handles concurrent connections from multiple OS processes.
      seed: 'mix run --no-start apps/identity/priv/repo/exo_seeds.exs',
      healthCheckPath: '/users/log-in',
      startTimeout: 30000,
    },
  ],
  // Active ZAP scans can take minutes; raise Cucumber step timeout accordingly.
  timeout: 300_000,
  adapters: {
    browser: {
      baseURL: 'http://localhost:4001',
      headless: true,
    },
    // HTTP adapter provides ${baseUrl} for security feature files.
    http: {
      baseURL: 'http://localhost:4001',
    },
    security: {
      zapUrl: 'http://localhost:8080',
      docker: {
        image: 'ghcr.io/zaproxy/zaproxy:stable',
        name: 'exo-bdd-zap-identity',
        network: 'host',
      },
    },
  },
})
