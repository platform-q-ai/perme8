import { Before, After } from '@cucumber/cucumber'
import { TestWorld } from '../world/index.ts'

// Tag-based hooks for specific adapter initialization

Before({ tags: '@http' }, async function (this: TestWorld) {
  if (!this.http) {
    throw new Error('HTTP adapter is not configured. Ensure http config is set in exo-bdd.config.ts')
  }
})

Before({ tags: '@browser' }, async function (this: TestWorld) {
  if (!this.browser) {
    throw new Error('Browser adapter is not configured. Ensure browser config is set in exo-bdd.config.ts')
  }
})

Before({ tags: '@cli' }, async function (this: TestWorld) {
  if (!this.cli) {
    throw new Error('CLI adapter is not configured. Ensure cli config is set in exo-bdd.config.ts')
  }
})

Before({ tags: '@graph' }, async function (this: TestWorld) {
  if (!this.graph) {
    throw new Error('Graph adapter is not configured. Ensure graph config is set in exo-bdd.config.ts')
  }
})

Before({ tags: '@security' }, async function (this: TestWorld) {
  if (!this.security) {
    throw new Error('Security adapter is not configured. Ensure security config is set in exo-bdd.config.ts')
  }
})

// Reset browser context between scenarios tagged @clean
After({ tags: '@clean' }, async function (this: TestWorld) {
  await this.browser?.clearContext()
})

// Create new security session for scenarios tagged @fresh-scan
Before({ tags: '@fresh-scan' }, async function (this: TestWorld) {
  await this.security?.newSession()
})
