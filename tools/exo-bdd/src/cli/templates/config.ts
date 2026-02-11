/**
 * Generates the content of an exo-bdd config file for a given project name.
 */
export function generateConfigContent(projectName: string): string {
  return `import { defineConfig } from 'exo-bdd'

export default defineConfig({
  features: './features/**/*.feature',
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
