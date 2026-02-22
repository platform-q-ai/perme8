import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

export default defineConfig({
  features: ['./features/**/*.feature'],
  servers: [
    {
      name: 'perme8-dashboard',
      command: 'mix phx.server',
      port: 4012,
      workingDir: '../../../',
      env: { MIX_ENV: 'test' },
      setup: 'cd apps/perme8_dashboard && mix assets.build',
      healthCheckPath: '/health',
      startTimeout: 30000,
    },
  ],
  timeout: 300_000,
  adapters: {
    browser: {
      baseURL: 'http://localhost:4012',
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
  variables: {},
})
