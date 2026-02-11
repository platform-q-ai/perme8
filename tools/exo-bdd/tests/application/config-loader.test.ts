import { test, expect, describe, beforeEach, afterEach } from 'bun:test'
import { loadConfig, defineConfig } from '../../src/application/config/ConfigLoader.ts'
import type { ExoBddConfig } from '../../src/application/config/ConfigSchema.ts'
import { resolve } from 'node:path'
import { writeFileSync, unlinkSync, mkdirSync, existsSync } from 'node:fs'

const tmpDir = resolve(import.meta.dir, '../../.tmp-test-configs')

describe('defineConfig', () => {
  test('returns the same config object', () => {
    const config: ExoBddConfig = {
      adapters: {
        http: { baseURL: 'https://api.example.com' },
      },
    }
    const result = defineConfig(config)
    expect(result).toBe(config)
    expect(result).toEqual(config)
  })

  test('provides type safety (identity function)', () => {
    const config = defineConfig({
      adapters: {
        http: { baseURL: 'http://localhost:3000' },
        cli: { workingDir: '/tmp' },
      },
    })
    expect(config.adapters.http?.baseURL).toBe('http://localhost:3000')
    expect(config.adapters.cli?.workingDir).toBe('/tmp')
  })
})

describe('loadConfig', () => {
  beforeEach(() => {
    if (!existsSync(tmpDir)) {
      mkdirSync(tmpDir, { recursive: true })
    }
  })

  afterEach(() => {
    // Clean up temp files
    try {
      const files = Bun.spawnSync(['ls', tmpDir]).stdout.toString().trim().split('\n')
      for (const file of files) {
        if (file) unlinkSync(resolve(tmpDir, file))
      }
      Bun.spawnSync(['rmdir', tmpDir])
    } catch {
      // ignore cleanup errors
    }
  })

  test('loadConfig loads from custom path', async () => {
    const configPath = resolve(tmpDir, 'test-config.ts')
    writeFileSync(
      configPath,
      `export default { adapters: { http: { baseURL: 'https://test.example.com' } } }`
    )
    const config = await loadConfig(configPath)
    expect(config.adapters.http?.baseURL).toBe('https://test.example.com')
  })

  test('loadConfig throws for missing config file', async () => {
    await expect(
      loadConfig(resolve(tmpDir, 'nonexistent.ts'))
    ).rejects.toThrow()
  })

  test('loadConfig returns parsed ExoBddConfig', async () => {
    const configPath = resolve(tmpDir, 'full-config.ts')
    writeFileSync(
      configPath,
      `export default {
        adapters: {
          http: { baseURL: 'http://localhost' },
          cli: { workingDir: '/tmp' },
        }
      }`
    )
    const config = await loadConfig(configPath)
    expect(config).toHaveProperty('adapters')
    expect(config.adapters).toHaveProperty('http')
    expect(config.adapters).toHaveProperty('cli')
  })

  test('loadConfig loads from default path when no arg provided', async () => {
    // This test verifies the default path resolution behavior
    // It will throw because exo-bdd.config.ts likely doesn't exist in cwd
    await expect(loadConfig()).rejects.toThrow()
  })
})
