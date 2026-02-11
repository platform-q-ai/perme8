import { test, expect, describe, mock } from 'bun:test'

// --- Capture registered hooks with their tags ---

interface TaggedHook {
  tags: string
  fn: (...args: any[]) => any
}

const capturedBefore: TaggedHook[] = []
const capturedAfter: TaggedHook[] = []

const mockBefore = mock((opts: { tags: string }, fn: (...args: any[]) => any) => {
  capturedBefore.push({ tags: opts.tags, fn })
})
const mockAfter = mock((opts: { tags: string }, fn: (...args: any[]) => any) => {
  capturedAfter.push({ tags: opts.tags, fn })
})

mock.module('@cucumber/cucumber', () => ({
  Before: mockBefore,
  After: mockAfter,
  World: class FakeWorld {
    constructor(_options: unknown) {}
  },
}))

// --- Import the tagged hooks module (triggers registration) ---

await import('../../../src/interface/hooks/tagged.ts')

// --- Helpers ---

function findBefore(tag: string): TaggedHook | undefined {
  return capturedBefore.find((h) => h.tags === tag)
}

function findAfter(tag: string): TaggedHook | undefined {
  return capturedAfter.find((h) => h.tags === tag)
}

// --- Tests ---

describe('Tagged hooks', () => {
  // --- @http ---

  test('@http Before hook throws when http adapter is missing', async () => {
    const hook = findBefore('@http')
    expect(hook).toBeDefined()

    const world = { http: undefined }
    await expect(hook!.fn.call(world)).rejects.toThrow('HTTP adapter is not configured')
  })

  test('@http Before hook passes when http adapter is present', async () => {
    const hook = findBefore('@http')!
    const world = { http: { get: mock(() => {}) } }
    await expect(hook.fn.call(world)).resolves.toBeUndefined()
  })

  // --- @browser ---

  test('@browser Before hook throws when browser adapter is missing', async () => {
    const hook = findBefore('@browser')
    expect(hook).toBeDefined()

    const world = { browser: undefined }
    await expect(hook!.fn.call(world)).rejects.toThrow('Browser adapter is not configured')
  })

  test('@browser Before hook passes when browser adapter is present', async () => {
    const hook = findBefore('@browser')!
    const world = { browser: { goto: mock(() => {}) } }
    await expect(hook.fn.call(world)).resolves.toBeUndefined()
  })

  // --- @cli ---

  test('@cli Before hook throws when cli adapter is missing', async () => {
    const hook = findBefore('@cli')
    expect(hook).toBeDefined()

    const world = { cli: undefined }
    await expect(hook!.fn.call(world)).rejects.toThrow('CLI adapter is not configured')
  })

  test('@cli Before hook passes when cli adapter is present', async () => {
    const hook = findBefore('@cli')!
    const world = { cli: { run: mock(() => {}) } }
    await expect(hook.fn.call(world)).resolves.toBeUndefined()
  })

  // --- @graph ---

  test('@graph Before hook throws when graph adapter is missing', async () => {
    const hook = findBefore('@graph')
    expect(hook).toBeDefined()

    const world = { graph: undefined }
    await expect(hook!.fn.call(world)).rejects.toThrow('Graph adapter is not configured')
  })

  test('@graph Before hook passes when graph adapter is present', async () => {
    const hook = findBefore('@graph')!
    const world = { graph: { query: mock(() => {}) } }
    await expect(hook.fn.call(world)).resolves.toBeUndefined()
  })

  // --- @security ---

  test('@security Before hook throws when security adapter is missing', async () => {
    const hook = findBefore('@security')
    expect(hook).toBeDefined()

    const world = { security: undefined }
    await expect(hook!.fn.call(world)).rejects.toThrow('Security adapter is not configured')
  })

  test('@security Before hook passes when security adapter is present', async () => {
    const hook = findBefore('@security')!
    const world = { security: { activeScan: mock(() => {}) } }
    await expect(hook.fn.call(world)).resolves.toBeUndefined()
  })

  // --- @clean ---

  test('@clean After hook clears browser context', async () => {
    const hook = findAfter('@clean')
    expect(hook).toBeDefined()

    const mockClearContext = mock(() => Promise.resolve())
    const world = { browser: { clearContext: mockClearContext } }

    await hook!.fn.call(world)

    expect(mockClearContext).toHaveBeenCalledTimes(1)
  })

  test('@clean After hook handles missing browser gracefully', async () => {
    const hook = findAfter('@clean')!
    const world = { browser: undefined }

    // Should not throw — uses optional chaining
    await expect(hook.fn.call(world)).resolves.toBeUndefined()
  })

  // --- @fresh-scan ---

  test('@fresh-scan Before hook creates new security session', async () => {
    const hook = findBefore('@fresh-scan')
    expect(hook).toBeDefined()

    const mockNewSession = mock(() => Promise.resolve())
    const world = { security: { newSession: mockNewSession } }

    await hook!.fn.call(world)

    expect(mockNewSession).toHaveBeenCalledTimes(1)
  })

  test('@fresh-scan Before hook handles missing security gracefully', async () => {
    const hook = findBefore('@fresh-scan')!
    const world = { security: undefined }

    // Should not throw — uses optional chaining
    await expect(hook.fn.call(world)).resolves.toBeUndefined()
  })
})
