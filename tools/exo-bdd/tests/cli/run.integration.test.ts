import { test, expect, describe, beforeEach, afterEach, mock } from 'bun:test'
import { resolve, basename, dirname } from 'node:path'
import { mkdirSync, existsSync, rmSync } from 'node:fs'
import { buildCucumberArgs, buildMessageFormatterArgs } from '../../src/cli/run.ts'
import type { ReportConfig } from '../../src/application/config/ConfigSchema.ts'

/**
 * Integration-style tests that verify the report config flows correctly
 * through buildCucumberArgs and that the output directory would be created.
 *
 * NOTE: We don't actually spawn cucumber-js -- we verify the args are built
 * correctly and the directory creation logic works.
 */

describe('runTests report config integration', () => {
  const tmpOutputDir = resolve('/tmp', `exo-bdd-test-${Date.now()}`)

  afterEach(() => {
    // Clean up any created directories
    try {
      if (existsSync(tmpOutputDir)) {
        rmSync(tmpOutputDir, { recursive: true })
      }
    } catch {
      // ignore
    }
  })

  test('buildCucumberArgs with report.message: true produces valid message formatter arg', () => {
    const args = buildCucumberArgs({
      features: './features/**/*.feature',
      configDir: '/project/bdd',
      setupPath: '/tmp/setup.ts',
      stepsImport: '/tools/exo-bdd/src/interface/steps/index.ts',
      passthrough: [],
      report: { message: true },
      configName: 'identity',
    })

    // Find the message format arg
    const formatIndices = args.reduce<number[]>((acc, v, i) => {
      if (v === '--format') acc.push(i)
      return acc
    }, [])

    const messageFormatIdx = formatIndices.find((i) => args[i + 1]?.startsWith('message:'))
    expect(messageFormatIdx).toBeDefined()

    const messageArg = args[messageFormatIdx! + 1]!
    const outputPath = messageArg.replace('message:', '')

    // Verify the path structure
    expect(outputPath).toContain('.exo-bdd-reports/')
    expect(outputPath).toContain('identity-')
    expect(outputPath).toEndWith('.ndjson')
  })

  test('buildCucumberArgs preserves all existing args alongside report config', () => {
    const args = buildCucumberArgs({
      features: './features/**/*.feature',
      configDir: '/project/bdd',
      setupPath: '/tmp/setup.ts',
      stepsImport: '/tools/exo-bdd/src/interface/steps/index.ts',
      passthrough: ['--format', 'progress'],
      tags: '@smoke and not @slow',
      noRetry: true,
      report: { message: true },
      configName: 'jarga',
    })

    // All original args should still be present
    expect(args).toContain('--import')
    expect(args).toContain('--tags')
    expect(args).toContain('@smoke and not @slow')
    expect(args).toContain('--retry')
    expect(args).toContain('0')
    expect(args).toContain('progress')

    // Message format should also be present
    const hasMessageFormat = args.some((v, i) =>
      v === '--format' && args[i + 1]?.startsWith('message:')
    )
    expect(hasMessageFormat).toBe(true)
  })

  test('output directory can be created with mkdirSync recursive', () => {
    const report: ReportConfig = { message: { outputDir: tmpOutputDir } }
    const args = buildMessageFormatterArgs(report, 'test-config')

    expect(args).toHaveLength(2)
    const outputPath = args[1]!.replace('message:', '')
    const outputDirFromPath = dirname(outputPath)

    // Create the directory (simulating what runTests would do)
    mkdirSync(outputDirFromPath, { recursive: true })
    expect(existsSync(outputDirFromPath)).toBe(true)
  })

  test('configName is extracted from config file basename', () => {
    // Simulate how runTests would extract a config name
    const configPath = '/project/apps/identity/test/bdd/exo-bdd-identity.config.ts'
    const configBasename = basename(configPath, '.config.ts')
    // Strip the 'exo-bdd-' prefix if present
    const configName = configBasename.replace(/^exo-bdd-/, '')

    expect(configName).toBe('identity')

    const args = buildMessageFormatterArgs({ message: true }, configName)
    expect(args[1]).toMatch(/identity-.*\.ndjson$/)
  })
})
