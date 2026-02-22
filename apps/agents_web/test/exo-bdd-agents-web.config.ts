import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

export default defineConfig({
  tags: 'not @wip',
  features: ['./features/**/*.browser.feature'],
  servers: [
    {
      name: 'agents-web',
      command: 'mix phx.server',
      port: 4015,
      workingDir: '../../../',
      env: { MIX_ENV: 'test' },
      setup: 'cd apps/agents_web && mix assets.build',
      seed: 'mix run --no-start apps/jarga/priv/repo/exo_seeds_web.exs',
      healthCheckPath: '/sessions',
      startTimeout: 30000,
    },
  ],
  timeout: 60_000,
  variables: {
    // Identity login URL (users log in via Identity, cookie is shared)
    identityUrl: 'http://localhost:4003',
    // AgentsWeb base URL
    baseUrl: 'http://localhost:4015',
    // Test user credentials (must match exo_seeds_web.exs)
    ownerEmail: 'alice@example.com',
    ownerPassword: 'hello world!',
  },
  adapters: {
    browser: {
      baseURL: 'http://localhost:4015',
      headless: true,
    },
  },
})
