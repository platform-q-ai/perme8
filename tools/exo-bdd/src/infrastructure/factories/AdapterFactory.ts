import type { ExoBddConfig } from '../../application/config/index.ts'
import type { Adapters } from '../../application/ports/Adapters.ts'
import { PlaywrightHttpAdapter } from '../adapters/http/PlaywrightHttpAdapter.ts'
import { PlaywrightBrowserAdapter } from '../adapters/browser/PlaywrightBrowserAdapter.ts'
import { BunCliAdapter } from '../adapters/cli/BunCliAdapter.ts'
import { Neo4jGraphAdapter } from '../adapters/graph/Neo4jGraphAdapter.ts'
import { ZapSecurityAdapter } from '../adapters/security/ZapSecurityAdapter.ts'

// Re-export the Adapters interface from the application layer
export type { Adapters } from '../../application/ports/Adapters.ts'

interface Disposable {
  dispose(): Promise<void>
}

export async function createAdapters(config: ExoBddConfig): Promise<Adapters> {
  const created: Disposable[] = []

  try {
    let http: PlaywrightHttpAdapter | undefined
    let browser: PlaywrightBrowserAdapter | undefined
    let cli: BunCliAdapter | undefined
    let graph: Neo4jGraphAdapter | undefined
    let security: ZapSecurityAdapter | undefined

    if (config.adapters.http) {
      http = new PlaywrightHttpAdapter(config.adapters.http)
      await http.initialize()
      created.push(http)
    }

    if (config.adapters.browser) {
      browser = new PlaywrightBrowserAdapter(config.adapters.browser)
      await browser.initialize()
      created.push(browser)
    }

    if (config.adapters.cli) {
      cli = new BunCliAdapter(config.adapters.cli)
      created.push(cli)
    }

    if (config.adapters.graph) {
      graph = new Neo4jGraphAdapter(config.adapters.graph)
      await graph.connect()
      created.push(graph)
    }

    if (config.adapters.security) {
      security = new ZapSecurityAdapter(config.adapters.security)
      created.push(security)
    }

    return {
      http,
      browser,
      cli,
      graph,
      security,
      async dispose() {
        await Promise.allSettled(created.map((a) => a.dispose()))
      },
    }
  } catch (error) {
    // Clean up any adapters that were successfully created before the failure
    await Promise.allSettled(created.map((a) => a.dispose()))
    throw error
  }
}
