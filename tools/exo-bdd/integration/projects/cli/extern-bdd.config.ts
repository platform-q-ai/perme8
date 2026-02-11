import { defineConfig } from '../../../src/index.ts'

export default defineConfig({
  adapters: {
    cli: {
      workingDir: process.cwd(),
    },
  },
})
