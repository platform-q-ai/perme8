import { resolve } from 'node:path'
import { existsSync, mkdirSync } from 'node:fs'

export interface ServeOptions {
  resultsDir: string
}

/**
 * Parses CLI arguments for the serve command.
 * Supports: --results-dir <path>
 */
export function parseServeArgs(args: string[]): ServeOptions {
  let resultsDir = 'allure-results'

  for (let i = 0; i < args.length; i++) {
    const arg = args[i]
    if (arg === '--results-dir') {
      resultsDir = args[++i] ?? resultsDir
    }
  }

  return { resultsDir }
}

/**
 * Launches `allure watch` to serve the Allure dashboard with live-reloading.
 * Monitors the results directory for new test results and auto-refreshes the browser.
 */
export async function serve(options: ServeOptions): Promise<number> {
  const exoBddRoot = resolve(import.meta.dir, '../../')
  const allureBin = resolve(exoBddRoot, 'node_modules/.bin/allure')
  const resultsDir = resolve(exoBddRoot, options.resultsDir)

  // Ensure the results directory exists so allure watch doesn't error
  // before any tests have been run
  if (!existsSync(resultsDir)) {
    mkdirSync(resultsDir, { recursive: true })
  }

  console.log(`Watching for Allure results in: ${resultsDir}`)
  console.log('Run tests with Allure enabled to see results in the dashboard.\n')

  const proc = Bun.spawn([allureBin, 'watch', resultsDir], {
    cwd: exoBddRoot,
    stdin: 'inherit',
    stdout: 'inherit',
    stderr: 'inherit',
    env: process.env,
  })

  return await proc.exited
}
