import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

export default defineConfig({
  features: ['./features/**/*.browser.feature'],
  servers: [
    {
      name: 'jarga-web',
      command: 'mix phx.server',
      port: 4002,
      workingDir: '../../../',
      env: { MIX_ENV: 'test' },
      seed: 'mix run --no-start apps/jarga/priv/repo/exo_seeds_web.exs',
      healthCheckPath: '/',
      startTimeout: 30000,
    },
  ],
  timeout: 120_000,
  variables: {
    // Test user credentials (must match exo_seeds_web.exs)
    ownerEmail: 'alice@example.com',
    ownerPassword: 'hello world!',
    adminEmail: 'bob@example.com',
    adminPassword: 'hello world!',
    memberEmail: 'charlie@example.com',
    memberPassword: 'hello world!',
    guestEmail: 'diana@example.com',
    guestPassword: 'hello world!',
    nonMemberEmail: 'eve@example.com',
    nonMemberPassword: 'hello world!',
    // Workspace slugs
    productTeamSlug: 'product-team',
    engineeringSlug: 'engineering',
  },
  adapters: {
    browser: {
      baseURL: 'http://localhost:4002',
      headless: true,
    },
  },
})
