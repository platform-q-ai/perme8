import { resolve, dirname, join } from 'node:path'
import { mkdirSync, existsSync, rmSync } from 'node:fs'
import { pathToFileURL } from 'node:url'
import type { ExoBddConfig } from '../application/config/index.ts'
import { ServerManager, DockerManager } from '../infrastructure/servers/index.ts'

export interface RunOptions {
  config: string
  tags?: string
  adapter?: string
  passthrough: string[]
}

export function parseRunArgs(args: string[]): RunOptions {
  let config: string | undefined
  let tags: string | undefined
  let adapter: string | undefined
  const passthrough: string[] = []

  for (let i = 0; i < args.length; i++) {
    const arg = args[i]
    if (arg === '--config' || arg === '-c') {
      config = args[++i]
    } else if (arg === '--tags' || arg === '-t') {
      tags = args[++i]
    } else if (arg === '--adapter' || arg === '-a') {
      adapter = args[++i]
    } else {
      passthrough.push(arg!)
    }
  }

  if (!config) {
    throw new Error('Missing required argument: --config <path>')
  }

  return { config, tags, adapter, passthrough }
}

/**
 * Filters feature glob patterns to only include files matching the given adapter suffix.
 *
 * For example, with adapter "browser":
 *   "./features/**\/*.browser.feature" => kept
 *   "./features/**\/*.security.feature" => removed
 *   "./features/**\/*.feature" => rewritten to "./features/**\/*.browser.feature"
 */
export function filterFeaturesByAdapter(features: string | string[], adapter: string): string[] {
  const patterns = Array.isArray(features) ? features : [features]
  const suffix = `.${adapter}.feature`

  const filtered: string[] = []
  for (const pattern of patterns) {
    if (pattern.endsWith(suffix)) {
      // Already matches the adapter — keep as-is
      filtered.push(pattern)
    } else if (pattern.endsWith('.feature')) {
      // Generic or different adapter glob — rewrite to target the requested adapter
      // e.g. "./features/**/*.feature" => "./features/**/*.browser.feature"
      // e.g. "./features/**/*.security.feature" => skip (different adapter)
      const base = pattern.slice(0, -'.feature'.length)
      // Check if the pattern already has an adapter suffix (e.g. ".security")
      const lastDot = base.lastIndexOf('.')
      const lastSlash = base.lastIndexOf('/')
      if (lastDot > lastSlash && lastDot > 0) {
        // Pattern has an explicit adapter suffix that doesn't match — skip it
        continue
      }
      // Generic glob like "*.feature" — rewrite to "*.browser.feature"
      filtered.push(`${base}${suffix}`)
    } else {
      filtered.push(pattern)
    }
  }

  return filtered
}

/**
 * Merges config-level tags with CLI-provided tags using AND semantics.
 * Returns undefined if neither is provided.
 */
export function mergeTags(configTags?: string, cliTags?: string): string | undefined {
  if (!configTags && !cliTags) return undefined
  if (!configTags) return cliTags
  if (!cliTags) return configTags
  return `(${configTags}) and (${cliTags})`
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
  tags?: string
}): string[] {
  const { features, configDir, setupPath, stepsImport, passthrough, tags } = options

  // Resolve feature paths relative to the config file directory
  const featurePaths = Array.isArray(features) ? features : [features]
  const resolvedFeatures = featurePaths.map((f) => resolve(configDir, f))

  const args: string[] = [
    ...resolvedFeatures,
    '--import',
    setupPath,
    '--import',
    stepsImport,
  ]

  // Add tag expression if configured
  if (tags) {
    args.push('--tags', tags)
  }

  args.push(...passthrough)

  return args
}

/**
 * Generates a temporary support/setup.ts file that wires the TestWorld,
 * loads config, creates adapters, and attaches them to the world.
 *
 * When adapter configs include a baseURL, it is automatically injected as a
 * variable so feature files can reference `${baseUrl}` without hardcoding it.
 */
export function generateSetupContent(configAbsPath: string, exoBddRoot: string, config?: ExoBddConfig): string {
  // Use file:// URLs for imports to ensure cross-platform compatibility
  const configUrl = pathToFileURL(configAbsPath).href
  const appConfigUrl = pathToFileURL(resolve(exoBddRoot, 'src/application/config/index.ts')).href
  const factoryUrl = pathToFileURL(resolve(exoBddRoot, 'src/infrastructure/factories/index.ts')).href
  const worldUrl = pathToFileURL(resolve(exoBddRoot, 'src/interface/world/index.ts')).href

  // Build variable injection lines
  const injections: string[] = []

  // Inject baseUrl from adapter configs
  if (config?.adapters.http?.baseURL) {
    injections.push(`  this.setVariable('baseUrl', '${config.adapters.http.baseURL}')`)
  }
  if (config?.adapters.browser?.baseURL) {
    injections.push(`  this.setVariable('browserBaseUrl', '${config.adapters.browser.baseURL}')`)
    // If no http baseUrl, use browser baseUrl as the primary baseUrl
    if (!config?.adapters.http?.baseURL) {
      injections.push(`  this.setVariable('baseUrl', '${config.adapters.browser.baseURL}')`)
    }
  }

  // Inject user-defined variables from config
  if (config?.variables) {
    for (const [name, value] of Object.entries(config.variables)) {
      // Escape single quotes in both name and value to prevent injection
      const escapedName = name.replace(/'/g, "\\'")
      const escaped = value.replace(/'/g, "\\'")
      injections.push(`  this.setVariable('${escapedName}', '${escaped}')`)
    }
  }

  const injectLines = injections.length > 0
    ? `\n  // Auto-injected from config\n${injections.join('\n')}\n`
    : ''

  // Build timeout line if configured
  const timeoutLine = config?.timeout
    ? `\nsetDefaultTimeout(${config.timeout})\n`
    : ''

  // Resolve VariableService URL for shared variable cleanup
  const variableServiceUrl = new URL('../../src/application/services/VariableService.ts', import.meta.url).href

  return `import { BeforeAll, AfterAll, Before, After, setWorldConstructor, setDefaultTimeout, Status } from '@cucumber/cucumber'
import { loadConfig } from '${appConfigUrl}'
import { createAdapters } from '${factoryUrl}'
import type { Adapters } from '${factoryUrl}'
import { TestWorld } from '${worldUrl}'
import { VariableService } from '${variableServiceUrl}'

setWorldConstructor(TestWorld)
${timeoutLine}

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
${injectLines}})

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
  VariableService.clearAll()
  await adapters?.dispose()
})
`
}

/**
 * Runs BDD tests using cucumber-js with the given config.
 * Returns the exit code from cucumber-js.
 *
 * Lifecycle:
 * 1. Load config
 * 2. Start configured servers (if any) and wait for health checks
 * 3. Run seed commands (if any)
 * 4. Run Cucumber tests
 * 5. Stop servers
 */
export async function runTests(options: RunOptions): Promise<number> {
  const configAbsPath = resolve(options.config)

  if (!existsSync(configAbsPath)) {
    console.error(`Config file not found: ${configAbsPath}`)
    return 1
  }

  const configDir = dirname(configAbsPath)
  const exoBddRoot = getExoBddRoot()

  // Load config to read features and servers
  let config: ExoBddConfig
  try {
    const configModule = await import(pathToFileURL(configAbsPath).href)
    config = configModule.default as ExoBddConfig
  } catch (error) {
    console.error(`Failed to load config: ${error instanceof Error ? error.message : String(error)}`)
    return 1
  }

  const rawFeatures = config.features ?? './features/**/*.feature'
  const features = options.adapter
    ? filterFeaturesByAdapter(rawFeatures, options.adapter)
    : rawFeatures

  // Start Docker containers (e.g. ZAP for security testing) if configured
  const dockerManager = new DockerManager()
  if (config.adapters.security?.docker) {
    try {
      await dockerManager.ensureZap(
        config.adapters.security.zapUrl,
        config.adapters.security.docker,
      )
    } catch (error) {
      console.error(`[exo-bdd] Failed to start ZAP container: ${error instanceof Error ? error.message : String(error)}`)
      await dockerManager.stopAll()
      return 1
    }
  }

  // Start servers if configured
  const serverManager = new ServerManager()
  if (config.servers && config.servers.length > 0) {
    try {
      await serverManager.startAll(config.servers, configDir)
    } catch (error) {
      console.error(`[exo-bdd] Failed to start servers: ${error instanceof Error ? error.message : String(error)}`)
      await serverManager.stopAll()
      await dockerManager.stopAll()
      return 1
    }
  }

  // Generate temporary setup file
  const tmpDir = join(exoBddRoot, '.tmp-runner')
  if (!existsSync(tmpDir)) {
    mkdirSync(tmpDir, { recursive: true })
  }
  const setupPath = join(tmpDir, 'setup.ts')
  const setupContent = generateSetupContent(configAbsPath, exoBddRoot, config)
  await Bun.write(setupPath, setupContent)

  // Build steps import path
  const stepsImport = resolve(exoBddRoot, 'src/interface/steps/index.ts')

  // Merge config-level tags with CLI-provided tags
  const effectiveTags = mergeTags(config.tags, options.tags)

  // Build cucumber-js args
  const cucumberArgs = buildCucumberArgs({
    features,
    configDir,
    setupPath,
    stepsImport,
    passthrough: options.passthrough,
    tags: effectiveTags,
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
    // Stop servers
    if (config.servers && config.servers.length > 0) {
      await serverManager.stopAll()
    }

    // Stop Docker containers that we started
    await dockerManager.stopAll()

    // Clean up temp directory
    try {
      rmSync(tmpDir, { recursive: true })
    } catch {
      // ignore cleanup errors
    }
  }
}
