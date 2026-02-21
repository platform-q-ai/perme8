import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

export default defineConfig({
  features: ['./features/**/*.browser.feature'],
  servers: [
    {
      name: 'exo-dashboard',
      command: 'mix phx.server',
      port: 4011,
      workingDir: '../../../',
      env: { MIX_ENV: 'test' },
      setup: 'cd apps/exo_dashboard && mix assets.build',
      healthCheckPath: '/',
      startTimeout: 30000,
    },
  ],
  timeout: 300_000,
  adapters: {
    browser: {
      baseURL: 'http://localhost:4011',
      headless: true,
    },
  },
})
