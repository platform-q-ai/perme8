import { resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

// Umbrella root is three levels up from apps/alkali/test/
// Use fileURLToPath for cross-runtime compatibility (Bun + Node/tsx)
const __dirname = dirname(fileURLToPath(import.meta.url))
const umbrellaRoot = resolve(__dirname, '..', '..', '..')
const testTmpDir = `/tmp/alkali-bdd-${process.pid}`

export default defineConfig({
  features: ['./features/**/*.cli.feature'],
  variables: {
    umbrellaRoot,
    testTmpDir,
  },
  adapters: {
    cli: {
      workingDir: umbrellaRoot,
    },
  },
})
