import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

export default defineConfig({
  features: ['./features/**/*.feature'],
  servers: [
    {
      name: 'perme8-dashboard',
      command: 'mix phx.server',
      port: 5012,
      workingDir: '../../../',
      env: { MIX_ENV: 'test' },
      setup: 'cd apps/perme8_dashboard && mix assets.build',
      seed: 'mix run --no-start apps/jarga/priv/repo/exo_seeds_web.exs',
      healthCheckPath: '/health',
      startTimeout: 30000,
    },
  ],
  timeout: 300_000,
  adapters: {
    browser: {
      baseURL: 'http://localhost:5012',
      headless: true,
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
  variables: {
    // Identity login URL (test.exs configures Identity at port 5001)
    identityUrl: 'http://localhost:5001',
    // Test user credentials (must match exo_seeds_web.exs)
    ownerEmail: 'alice@example.com',
    ownerPassword: 'hello world!',
    memberEmail: 'bob@example.com',
    memberPassword: 'hello world!',
  },
})
