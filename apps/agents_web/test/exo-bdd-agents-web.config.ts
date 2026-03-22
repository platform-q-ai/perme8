import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

export default defineConfig({
  features: ['./features/**/*.browser.feature'],
  servers: [
    {
      name: 'agents-web',
      command: 'mix phx.server',
      port: 5014,
      workingDir: '../../../',
      env: { MIX_ENV: 'test' },
      setup: 'cd apps/agents_web && mix assets.build',
      seed: 'mix run --no-start apps/jarga/priv/repo/exo_seeds_web.exs',
      healthCheckPath: '/health',
      startTimeout: 30000,
    },
  ],
  timeout: 60_000,
  variables: {
    // Identity login URL (runtime.exs overrides Identity to port 4001 for all envs)
    identityUrl: 'http://localhost:5001',
    // AgentsWeb base URL
    baseUrl: 'http://localhost:5014',
    // Test user credentials (must match exo_seeds_web.exs)
    ownerEmail: 'alice@example.com',
    ownerPassword: 'hello world!',
    // Primary dashboard user for browser scenarios
    memberEmail: 'alice@example.com',
    memberPassword: 'hello world!',
  },
  adapters: {
    browser: {
      baseURL: 'http://localhost:5014',
      headless: true,
    },
  },
})
