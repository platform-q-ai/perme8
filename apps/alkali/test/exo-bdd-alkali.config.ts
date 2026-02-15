import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

export default defineConfig({
  features: ['./features/**/*.cli.feature'],
  adapters: {
    cli: {},
  },
})
