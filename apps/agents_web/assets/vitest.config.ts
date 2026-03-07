import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'happy-dom',
    globals: true,
    pool: 'forks',
    maxForks: 4,
    minForks: 1,
    execArgv: ['--max-old-space-size=2048'],
    isolate: true,
    testTimeout: 10000,
    hookTimeout: 10000,
  },
})
