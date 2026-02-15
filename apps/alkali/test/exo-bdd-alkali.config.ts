import { resolve } from 'node:path'
import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

// Umbrella root is three levels up from apps/alkali/test/
const umbrellaRoot = resolve(import.meta.dir, '..', '..', '..')
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
