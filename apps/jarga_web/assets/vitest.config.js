import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'happy-dom',
    globals: true,

    // Prevent memory exhaustion from parallel test execution
    pool: 'forks',
    poolOptions: {
      forks: {
        // Limit concurrent workers to prevent OOM
        // Adjust based on your system memory (you have 30GB)
        maxForks: 4,
        minForks: 1,

        // Memory limit per worker (in MB)
        // Set to ~2GB per worker to prevent runaway processes
        execArgv: ['--max-old-space-size=2048'],
      },
    },

    // Isolate tests to prevent memory leaks between test files
    isolate: true,

    // Timeout for tests that might hang
    testTimeout: 10000, // 10 seconds
    hookTimeout: 10000,
  },
})
