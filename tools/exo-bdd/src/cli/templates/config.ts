/**
 * Generates the content of an exo-bdd config file for a given project name.
 */
export function generateConfigContent(projectName: string): string {
  return `import { defineConfig } from 'exo-bdd'

export default defineConfig({
  features: './features/**/*.feature',
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
    // http: {
    //   baseURL: 'http://localhost:4000',
    // },
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
    // security: {
    //   zapUrl: 'http://localhost:8080',
    // },
  },
})
`
}

/**
 * Returns the config file name for a given project name.
 */
export function configFileName(projectName: string): string {
  return `exo-bdd-${projectName}.config.ts`
}
