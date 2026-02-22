import { defineConfig } from 'exo-bdd'

export default defineConfig({
  features: './**/*.feature',
  servers: [
    {
      name: 'jarga-api',
      command: 'mix phx.server',
      port: 4000,
      workingDir: '../../',
      env: { MIX_ENV: 'test' },
      seed: 'mix run priv/repo/seeds.exs',
      healthCheckPath: '/api/health',
      startTimeout: 30000,
    },
  ],
  adapters: {
    http: {
      baseURL: 'http://localhost:4000',
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
  timeout: 300_000,
})
