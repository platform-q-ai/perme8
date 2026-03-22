import { defineConfig } from 'exo-bdd'

export default defineConfig({
  features: './**/*.feature',
  timeout: 300_000,
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
})
