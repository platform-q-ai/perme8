import type { ServerConfig } from '../../application/config/index.ts'
import type { Subprocess } from 'bun'
import { resolve } from 'node:path'

interface ManagedServer {
  config: ServerConfig
  process: Subprocess
}

/**
 * Manages the lifecycle of external servers required by tests.
 *
 * Responsibilities:
 * - Start server processes from config
 * - Poll health-check endpoints until ready
 * - Run seed commands after servers are healthy
 * - Shut down all servers on dispose
 */
export class ServerManager {
  private servers: ManagedServer[] = []

  /**
   * Start all configured servers, wait for health checks, and run seeds.
   * @param configs  Server configurations from ExoBddConfig.servers
   * @param configDir  Directory of the config file (for resolving relative workingDir)
   */
  async startAll(configs: ServerConfig[], configDir: string): Promise<void> {
    for (const config of configs) {
      await this.startServer(config, configDir)
    }
  }

  /**
   * Stop all managed servers by killing their processes.
   */
  async stopAll(): Promise<void> {
    const errors: Error[] = []

    for (const server of this.servers) {
      try {
        server.process.kill()
        // Give the process a moment to exit
        await Promise.race([
          server.process.exited,
          sleep(5000),
        ])
        console.log(`[exo-bdd] Stopped server: ${server.config.name}`)
      } catch (error) {
        errors.push(
          new Error(
            `Failed to stop server "${server.config.name}": ${error instanceof Error ? error.message : String(error)}`
          )
        )
      }
    }

    this.servers = []

    if (errors.length > 0) {
      console.error(`[exo-bdd] Errors stopping servers:`, errors.map((e) => e.message).join(', '))
    }
  }

  private async startServer(config: ServerConfig, configDir: string): Promise<void> {
    const cwd = config.workingDir ? resolve(configDir, config.workingDir) : configDir

    console.log(`[exo-bdd] Starting server: ${config.name} (port ${config.port})`)
    console.log(`[exo-bdd]   command: ${config.command}`)
    console.log(`[exo-bdd]   cwd: ${cwd}`)

    const proc = Bun.spawn(['sh', '-c', config.command], {
      cwd,
      env: { ...process.env, ...config.env },
      stdout: 'inherit',
      stderr: 'inherit',
    })

    this.servers.push({ config, process: proc })

    // Wait for the server to become healthy
    await this.waitForHealthy(config)

    // Run seed command if provided
    if (config.seed) {
      console.log(`[exo-bdd] Running seed for ${config.name}: ${config.seed}`)
      const seedResult = Bun.spawnSync(['sh', '-c', config.seed], {
        cwd,
        env: { ...process.env, ...config.env },
        stdout: 'inherit',
        stderr: 'inherit',
      })

      if (seedResult.exitCode !== 0) {
        throw new Error(
          `Seed command for "${config.name}" failed with exit code ${seedResult.exitCode}`
        )
      }
      console.log(`[exo-bdd] Seed complete for ${config.name}`)
    }
  }

  private async waitForHealthy(config: ServerConfig): Promise<void> {
    const timeout = config.startTimeout ?? 30_000
    const healthPath = config.healthCheckPath ?? '/'
    const url = `http://localhost:${config.port}${healthPath}`
    const deadline = Date.now() + timeout
    const pollInterval = 500

    console.log(`[exo-bdd] Waiting for ${config.name} to be healthy at ${url}...`)

    while (Date.now() < deadline) {
      try {
        const response = await fetch(url, {
          signal: AbortSignal.timeout(2000),
        })
        // Any HTTP response (including 4xx) means the server is up and listening.
        // Auth-protected health check paths (e.g., API behind bearer tokens) will
        // return 401/403, but the server is still healthy.
        if (response.ok) {
          console.log(`[exo-bdd] Server ${config.name} is healthy (status ${response.status})`)
          return
        }
        if (response.status >= 400 && response.status < 500) {
          console.log(
            `[exo-bdd] Server ${config.name} is reachable (status ${response.status}) — ` +
            `treating as healthy (auth-protected endpoint)`
          )
          return
        }
      } catch {
        // Server not ready yet -- connection refused or timeout
      }
      await sleep(pollInterval)
    }

    throw new Error(
      `Server "${config.name}" did not become healthy within ${timeout}ms. ` +
      `Health check URL: ${url}`
    )
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
