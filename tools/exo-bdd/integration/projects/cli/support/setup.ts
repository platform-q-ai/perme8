import { BeforeAll, AfterAll, Before, setWorldConstructor } from '@cucumber/cucumber'
import { loadConfig, createAdapters, TestWorld } from '../../../../src/index.ts'
import type { Adapters } from '../../../../src/index.ts'
import { resolve } from 'node:path'

// CLI step definitions
import '../../../../src/interface/steps/cli/index.ts'

// Variable step definitions (for interpolation scenarios)
import '../../../../src/interface/steps/variables.steps.ts'

setWorldConstructor(TestWorld)

let adapters: Adapters

BeforeAll(async function () {
  const configPath = resolve(import.meta.dir, '..', 'exo-bdd.config.ts')
  const config = await loadConfig(configPath)
  adapters = await createAdapters(config)
})

Before(async function (this: TestWorld) {
  if (adapters.cli) this.cli = adapters.cli
  this.reset()
})

AfterAll(async function () {
  await adapters?.dispose()
})
