import { defineConfig } from 'exo-bdd'

export default defineConfig({
  features: './**/*.feature',
  // servers: [
  //   {
  //     name: 'my-app',
  //     command: 'mix phx.server',
  //     port: 4000,
  //     workingDir: '../../',
  //     env: { MIX_ENV: 'test' },
  //     seed: 'mix run priv/repo/seeds.exs',
  //     healthCheckPath: '/api/health',
  //     startTimeout: 30000,
  //   },
  // ],
  adapters: {
    browser: {
      baseURL: 'http://localhost:4000',
      headless: true,
    },
    // cli: {
    //   workingDir: process.cwd(),
    // },
    // graph: {
    //   uri: 'bolt://localhost:7687',
    //   username: 'neo4j',
    //   password: 'password',
    // },
    // security: {
    //   zapUrl: 'http://localhost:8080',
    // },
  },
})
