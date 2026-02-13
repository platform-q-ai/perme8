import type { ZapDockerConfig } from '../../application/config/index.ts'

const DEFAULTS = {
  image: 'ghcr.io/zaproxy/zaproxy:stable',
  name: 'exo-bdd-zap',
  network: 'host',
  startTimeout: 60_000,
} as const

/**
 * Manages Docker containers required by adapters (currently ZAP for security testing).
 *
 * Lifecycle:
 * 1. Check if ZAP is already reachable at the configured URL
 * 2. If not, check if a container with the configured name is already running
 * 3. If not, start a new container
 * 4. Wait for ZAP's API to become ready
 * 5. After tests complete, stop the container (only if we started it)
 */
export class DockerManager {
  private managedContainers: string[] = []

  /**
   * Ensure ZAP is running and reachable. Starts a Docker container if needed.
   *
   * @param zapUrl  The ZAP API URL (e.g. "http://localhost:8080")
   * @param docker  Docker configuration from the security adapter config
   */
  async ensureZap(zapUrl: string, docker: ZapDockerConfig): Promise<void> {
    const port = docker.port ?? this.extractPort(zapUrl)
    const image = docker.image ?? DEFAULTS.image
    const name = docker.name ?? DEFAULTS.name
    const network = docker.network ?? DEFAULTS.network
    const startTimeout = docker.startTimeout ?? DEFAULTS.startTimeout

    // 1. Check if ZAP is already reachable
    if (await this.isZapReady(zapUrl)) {
      console.log(`[exo-bdd] ZAP already reachable at ${zapUrl}`)
      return
    }

    // 2. Check if container exists but is stopped
    if (await this.containerExists(name)) {
      const running = await this.containerIsRunning(name)
      if (running) {
        // Container is running but ZAP API isn't ready yet — wait for it
        console.log(`[exo-bdd] Container "${name}" is running, waiting for ZAP API...`)
        await this.waitForZap(zapUrl, startTimeout)
        return
      }

      // Remove stopped container so we can start fresh
      console.log(`[exo-bdd] Removing stopped container "${name}"...`)
      await this.exec(['docker', 'rm', name])
    }

    // 3. Ensure image is available
    await this.ensureImage(image)

    // 4. Start container
    console.log(`[exo-bdd] Starting ZAP container "${name}" (image: ${image}, port: ${port})`)
    const args = [
      'docker', 'run', '-d',
      '--name', name,
      '--network', network,
      '-u', 'zap',
    ]

    // When not using host network, map the port
    if (network !== 'host') {
      args.push('-p', `${port}:${port}`)
    }

    args.push(
      image,
      'zap.sh', '-daemon',
      '-host', '0.0.0.0',
      '-port', String(port),
      '-config', 'api.addrs.addr.name=.*',
      '-config', 'api.addrs.addr.regex=true',
      '-config', 'api.disablekey=true',
    )

    await this.exec(args)
    this.managedContainers.push(name)

    // 5. Wait for ZAP to become ready
    await this.waitForZap(zapUrl, startTimeout)
  }

  /**
   * Stop and remove all containers that were started by this manager.
   */
  async stopAll(): Promise<void> {
    for (const name of this.managedContainers) {
      try {
        console.log(`[exo-bdd] Stopping ZAP container "${name}"...`)
        await this.exec(['docker', 'stop', name])
        await this.exec(['docker', 'rm', name])
        console.log(`[exo-bdd] Removed ZAP container "${name}"`)
      } catch (error) {
        console.error(
          `[exo-bdd] Failed to stop container "${name}": ${error instanceof Error ? error.message : String(error)}`
        )
      }
    }
    this.managedContainers = []
  }

  private extractPort(url: string): number {
    try {
      const parsed = new URL(url)
      return parsed.port ? parseInt(parsed.port, 10) : 8080
    } catch {
      return 8080
    }
  }

  private async isZapReady(zapUrl: string): Promise<boolean> {
    try {
      const response = await fetch(`${zapUrl}/JSON/core/view/version/`, {
        signal: AbortSignal.timeout(2000),
      })
      if (response.ok) {
        const data = await response.json() as { version: string }
        if (data.version) return true
      }
      return false
    } catch {
      return false
    }
  }

  private async waitForZap(zapUrl: string, timeoutMs: number): Promise<void> {
    const deadline = Date.now() + timeoutMs
    const pollInterval = 1000

    console.log(`[exo-bdd] Waiting for ZAP API at ${zapUrl}...`)

    while (Date.now() < deadline) {
      if (await this.isZapReady(zapUrl)) {
        console.log(`[exo-bdd] ZAP is ready`)
        return
      }
      await sleep(pollInterval)
    }

    throw new Error(
      `ZAP did not become ready within ${timeoutMs}ms at ${zapUrl}`
    )
  }

  private async containerExists(name: string): Promise<boolean> {
    try {
      const result = Bun.spawnSync(
        ['docker', 'inspect', '--format', '{{.State.Status}}', name],
        { stdout: 'pipe', stderr: 'pipe' }
      )
      return result.exitCode === 0
    } catch {
      return false
    }
  }

  private async containerIsRunning(name: string): Promise<boolean> {
    try {
      const result = Bun.spawnSync(
        ['docker', 'inspect', '--format', '{{.State.Running}}', name],
        { stdout: 'pipe', stderr: 'pipe' }
      )
      return result.exitCode === 0 && result.stdout.toString().trim() === 'true'
    } catch {
      return false
    }
  }

  private async ensureImage(image: string): Promise<void> {
    // Check if image exists locally
    const inspect = Bun.spawnSync(['docker', 'image', 'inspect', image], {
      stdout: 'pipe',
      stderr: 'pipe',
    })

    if (inspect.exitCode === 0) return

    console.log(`[exo-bdd] Pulling Docker image: ${image}`)
    await this.exec(['docker', 'pull', image])
  }

  private async exec(args: string[]): Promise<string> {
    const proc = Bun.spawnSync(args, {
      stdout: 'pipe',
      stderr: 'pipe',
    })

    if (proc.exitCode !== 0) {
      const stderr = proc.stderr.toString().trim()
      throw new Error(
        `Command failed (exit ${proc.exitCode}): ${args.join(' ')}\n${stderr}`
      )
    }

    return proc.stdout.toString().trim()
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
