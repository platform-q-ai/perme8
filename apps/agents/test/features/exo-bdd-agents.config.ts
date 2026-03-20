import { defineConfig } from 'exo-bdd'

export default defineConfig({
  features: './**/*.feature',
  servers: [
    {
      name: 'agents',
      command: 'mix phx.server',
      port: 4000,
      workingDir: '../../..',
      env: { MIX_ENV: 'test' },
      healthCheckPath: '/mcp/health',
      startTimeout: 30000,
    },
  ],
  adapters: {
    http: {
      baseURL: 'http://localhost:4000/mcp',
    },
    // browser: {
    //   baseURL: 'http://localhost:4000',
    //   headless: true,
    // },
    // cli: {
    //   workingDir: process.cwd(),
    // },
    // graph: {
    //   uri: 'bolt://localhost:7687',
    //   username: 'neo4j',
    //   password: 'password',
    // },
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
