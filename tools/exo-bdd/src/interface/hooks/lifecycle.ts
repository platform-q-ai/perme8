import { BeforeAll, AfterAll, Before, After, setWorldConstructor, Status } from '@cucumber/cucumber'
import { mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { loadConfig } from '../../application/config/index.ts'
import { createAdapters, type Adapters } from '../../infrastructure/factories/index.ts'
import { TestWorld } from '../world/index.ts'
import { VariableService } from '../../application/services/VariableService.ts'

setWorldConstructor(TestWorld)

let adapters: Adapters
const failureDir = join(process.cwd(), 'test-failures')

BeforeAll(async function () {
  const config = await loadConfig()
  adapters = await createAdapters(config)
  mkdirSync(failureDir, { recursive: true })
})

Before(async function (this: TestWorld) {
  // Attach adapters
  if (adapters.http) this.http = adapters.http
  if (adapters.browser) this.browser = adapters.browser
  if (adapters.cli) this.cli = adapters.cli
  if (adapters.graph) this.graph = adapters.graph
  if (adapters.security) this.security = adapters.security

  // Reset scenario state
  this.reset()
})

After(async function (this: TestWorld, scenario) {
  if (this.hasBrowser) {
    if (scenario.result?.status === Status.FAILED) {
      const slug = (scenario.pickle.name || 'unknown')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-|-$/g, '')
        .slice(0, 80)

      try {
        // If there are named sessions, capture artifacts from each
        const sessionNames = this.browser.sessionNames
        if (sessionNames.length > 0) {
          for (const name of sessionNames) {
            this.browser.switchTo(name)
            const screenshot = await this.browser.screenshot({ fullPage: true })
            this.attach(screenshot, 'image/png')
            writeFileSync(join(failureDir, `${slug}--${name}.png`), screenshot)

            const html = await this.browser.page.content()
            writeFileSync(join(failureDir, `${slug}--${name}.html`), html, 'utf-8')

            const url = this.browser.url()
            writeFileSync(
              join(failureDir, `${slug}--${name}.meta.txt`),
              `URL: ${url}\nScenario: ${scenario.pickle.name}\nSession: ${name}\n`,
              'utf-8',
            )
          }
        } else {
          // Single-browser scenario: capture from default page
          const screenshot = await this.browser.screenshot({ fullPage: true })
          this.attach(screenshot, 'image/png')
          writeFileSync(join(failureDir, `${slug}.png`), screenshot)

          const html = await this.browser.page.content()
          writeFileSync(join(failureDir, `${slug}.html`), html, 'utf-8')

          const url = this.browser.url()
          writeFileSync(
            join(failureDir, `${slug}.meta.txt`),
            `URL: ${url}\nScenario: ${scenario.pickle.name}\n`,
            'utf-8',
          )
        }
      } catch (artifactError) {
        console.error('[exo-bdd] Failed to save failure artifacts:', artifactError)
      }
    }
    await this.browser.clearContext()
  }
})

AfterAll(async function () {
  VariableService.clearAll()
  await adapters?.dispose()
})
