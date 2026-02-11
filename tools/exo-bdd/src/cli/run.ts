import { resolve, dirname, join } from 'node:path'
import { mkdirSync, existsSync, rmSync } from 'node:fs'
import { pathToFileURL } from 'node:url'

export interface RunOptions {
  config: string
  passthrough: string[]
}

export function parseRunArgs(args: string[]): RunOptions {
  let config: string | undefined
  const passthrough: string[] = []

  for (let i = 0; i < args.length; i++) {
    const arg = args[i]
    if (arg === '--config' || arg === '-c') {
      config = args[++i]
    } else {
      passthrough.push(arg!)
    }
  }

  if (!config) {
    throw new Error('Missing required argument: --config <path>')
  }

  return { config, passthrough }
}

/**
 * Resolves the exo-bdd package root directory (where node_modules lives).
 */
function getExoBddRoot(): string {
  // This file is at src/cli/run.ts, so root is two levels up
  return resolve(import.meta.dir, '..', '..')
}

/**
 * Builds the cucumber-js CLI arguments from a config and options.
 * Exported for testing.
 */
export function buildCucumberArgs(options: {
  features: string | string[]
  configDir: string
  setupPath: string
  stepsImport: string
  passthrough: string[]
}): string[] {
  const { features, configDir, setupPath, stepsImport, passthrough } = options

  // Resolve feature paths relative to the config file directory
  const featurePaths = Array.isArray(features) ? features : [features]
  const resolvedFeatures = featurePaths.map((f) => resolve(configDir, f))

  const args: string[] = [
    ...resolvedFeatures,
    '--import',
    setupPath,
    '--import',
    stepsImport,
    ...passthrough,
  ]

  return args
}

/**
 * Generates a temporary support/setup.ts file that wires the TestWorld,
 * loads config, creates adapters, and attaches them to the world.
 */
export function generateSetupContent(configAbsPath: string, exoBddRoot: string): string {
  // Use file:// URLs for imports to ensure cross-platform compatibility
  const configUrl = pathToFileURL(configAbsPath).href
  const appConfigUrl = pathToFileURL(resolve(exoBddRoot, 'src/application/config/index.ts')).href
  const factoryUrl = pathToFileURL(resolve(exoBddRoot, 'src/infrastructure/factories/index.ts')).href
  const worldUrl = pathToFileURL(resolve(exoBddRoot, 'src/interface/world/index.ts')).href

  return `import { BeforeAll, AfterAll, Before, After, setWorldConstructor, Status } from '@cucumber/cucumber'
import { loadConfig } from '${appConfigUrl}'
import { createAdapters } from '${factoryUrl}'
import type { Adapters } from '${factoryUrl}'
import { TestWorld } from '${worldUrl}'

setWorldConstructor(TestWorld)

let adapters: Adapters

BeforeAll(async function () {
  const configModule = await import('${configUrl}')
  const config = configModule.default
  adapters = await createAdapters(config)
})

Before(async function (this: TestWorld) {
  if (adapters.http) this.http = adapters.http
  if (adapters.browser) this.browser = adapters.browser
  if (adapters.cli) this.cli = adapters.cli
  if (adapters.graph) this.graph = adapters.graph
  if (adapters.security) this.security = adapters.security
  this.reset()
})

After(async function (this: TestWorld, scenario) {
  if (this.hasBrowser) {
    if (scenario.result?.status === Status.FAILED) {
      const screenshot = await this.browser.screenshot()
      this.attach(screenshot, 'image/png')
    }
    await this.browser.clearContext()
  }
})

AfterAll(async function () {
  await adapters?.dispose()
})
`
}

/**
 * Runs BDD tests using cucumber-js with the given config.
 * Returns the exit code from cucumber-js.
 */
export async function runTests(options: RunOptions): Promise<number> {
  const configAbsPath = resolve(options.config)

  if (!existsSync(configAbsPath)) {
    console.error(`Config file not found: ${configAbsPath}`)
    return 1
  }

  const configDir = dirname(configAbsPath)
  const exoBddRoot = getExoBddRoot()

  // Load config to read features
  let features: string | string[] = './features/**/*.feature'
  try {
    const configModule = await import(pathToFileURL(configAbsPath).href)
    const config = configModule.default
    if (config.features) {
      features = config.features
    }
  } catch (error) {
    console.error(`Failed to load config: ${error instanceof Error ? error.message : String(error)}`)
    return 1
  }

  // Generate temporary setup file
  const tmpDir = join(exoBddRoot, '.tmp-runner')
  if (!existsSync(tmpDir)) {
    mkdirSync(tmpDir, { recursive: true })
  }
  const setupPath = join(tmpDir, 'setup.ts')
  const setupContent = generateSetupContent(configAbsPath, exoBddRoot)
  await Bun.write(setupPath, setupContent)

  // Build steps import path
  const stepsImport = resolve(exoBddRoot, 'src/interface/steps/index.ts')

  // Build cucumber-js args
  const cucumberArgs = buildCucumberArgs({
    features,
    configDir,
    setupPath,
    stepsImport,
    passthrough: options.passthrough,
  })

  const cucumberBin = resolve(exoBddRoot, 'node_modules/.bin/cucumber-js')

  try {
    const proc = Bun.spawn([cucumberBin, ...cucumberArgs], {
      cwd: exoBddRoot,
      stdout: 'inherit',
      stderr: 'inherit',
      env: {
        ...process.env,
        NODE_OPTIONS: '--import tsx',
      },
    })

    const exitCode = await proc.exited
    return exitCode
  } finally {
    // Clean up temp directory
    try {
      rmSync(tmpDir, { recursive: true })
    } catch {
      // ignore cleanup errors
    }
  }
}
