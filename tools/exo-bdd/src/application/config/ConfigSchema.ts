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
}
