import { BeforeAll, AfterAll, Before, After, setWorldConstructor, Status } from '@cucumber/cucumber'
import { loadConfig } from '../../application/config/index.ts'
import { createAdapters, type Adapters } from '../../infrastructure/factories/index.ts'
import { TestWorld } from '../world/index.ts'
import { VariableService } from '../../application/services/VariableService.ts'

setWorldConstructor(TestWorld)

let adapters: Adapters

BeforeAll(async function () {
  const config = await loadConfig()
  adapters = await createAdapters(config)
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
