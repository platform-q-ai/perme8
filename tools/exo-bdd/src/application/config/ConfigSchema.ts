/**
 * Allure report configuration.
 * - `true` enables Allure with default settings (results written to `allure-results/`)
 * - An object enables Allure with custom options
 * - `false` or omitted disables Allure
 */
export type AllureReportConfig = boolean | {
  /** Directory for Allure result files. Defaults to 'allure-results'. */
  resultsDir?: string
}

export interface ReportConfig {
  /** Enable Allure test reporting. */
  allure?: AllureReportConfig
}

export interface ExoBddConfig {
  /** Glob or path(s) to feature files. Used by the CLI runner to locate .feature files. */
  features?: string | string[]
  /** Servers to start before running tests and stop afterwards. */
  servers?: ServerConfig[]
  /**
   * Variables to pre-seed into every scenario's TestWorld.
   * These are available as `${name}` in feature file steps.
   * Useful for injecting API keys, tokens, or environment-specific values.
   */
  variables?: Record<string, string>
  /**
   * Default Cucumber step timeout in milliseconds.
   * Defaults to Cucumber's built-in 5000ms. Set higher for security scans
   * (e.g., 300000 for active ZAP scanning).
   */
  timeout?: number
  /**
   * Cucumber tag expression to filter scenarios.
   * Examples: "not @neo4j", "@smoke", "@api and not @slow"
   * Passed directly to cucumber-js as --tags.
   */
  tags?: string
  /**
   * Reporting configuration. Controls which reporters/formatters are enabled.
   */
  report?: ReportConfig
  adapters: {
    http?: HttpAdapterConfig
    browser?: BrowserAdapterConfig
    cli?: CliAdapterConfig
    graph?: GraphAdapterConfig
    security?: SecurityAdapterConfig
  }
}

export interface ServerConfig {
  /** Human-readable name for log output (e.g. "jarga_api"). */
  name: string
  /** Shell command to start the server (e.g. "mix phx.server"). */
  command: string
  /** Port the server listens on. Used for the health check. */
  port: number
  /** Working directory for the command. Resolved relative to the config file. */
  workingDir?: string
  /** Environment variables to set when starting the server. */
  env?: Record<string, string>
  /**
   * Shell command to run after the server is healthy (e.g. "mix run priv/repo/exo_seeds.exs").
   * Useful for seeding a database with test fixtures.
   */
  seed?: string
  /**
   * Shell command to run before starting the server (e.g. "mix assets.build").
   * Runs synchronously in the same cwd and env as the server command.
   * Useful for compiling assets that have no watcher in test mode.
   */
  setup?: string
  /** Health-check URL path to poll until the server is ready. Defaults to "/". */
  healthCheckPath?: string
  /** Maximum time in ms to wait for the server to become healthy. Defaults to 30000. */
  startTimeout?: number
}

export interface HttpAdapterConfig {
  baseURL: string
  timeout?: number
  headers?: Record<string, string>
  auth?: {
    type: 'bearer' | 'basic'
    token?: string
    username?: string
    password?: string
  }
}

export interface BrowserAdapterConfig {
  baseURL: string
  headless?: boolean
  viewport?: { width: number; height: number }
  screenshot?: 'always' | 'only-on-failure' | 'never'
  video?: 'on' | 'off' | 'retain-on-failure'
}

export interface CliAdapterConfig {
  workingDir?: string
  env?: Record<string, string>
  timeout?: number
  shell?: string
}

export interface GraphAdapterConfig {
  uri: string
  username: string
  password: string
  database?: string
}

export interface SecurityAdapterConfig {
  zapUrl: string
  zapApiKey?: string
  /** Polling interval in ms for scan loops. Defaults to 1000–2000 depending on scan type. Set to 0 in tests. */
  pollDelayMs?: number
  /** Maximum time in ms to wait for a scan to complete. Defaults to 300000 (5 minutes). */
  scanTimeout?: number
  /**
   * Docker configuration for auto-managing a ZAP container.
   * When provided, the runner will check if ZAP is reachable at `zapUrl`.
   * If not, it starts a Docker container automatically and stops it after tests complete.
   */
  docker?: ZapDockerConfig
}

export interface ZapDockerConfig {
  /** Docker image to use. Defaults to "ghcr.io/zaproxy/zaproxy:stable". */
  image?: string
  /** Container name. Defaults to "exo-bdd-zap". */
  name?: string
  /** Port to expose ZAP on. Extracted from `zapUrl` if not provided. */
  port?: number
  /**
   * Network mode for the container (e.g. "host", "bridge").
   * Use "host" when ZAP needs to reach servers on localhost.
   * Defaults to "host".
   */
  network?: string
  /** Maximum time in ms to wait for ZAP to become ready. Defaults to 60000. */
  startTimeout?: number
}
