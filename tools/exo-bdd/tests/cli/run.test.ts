import { test, expect, describe } from 'bun:test'
import { resolve } from 'node:path'
import { parseRunArgs, buildCucumberArgs, generateSetupContent } from '../../src/cli/run.ts'

describe('parseRunArgs', () => {
  test('parses --config flag', () => {
    const opts = parseRunArgs(['--config', 'path/to/config.ts'])
    expect(opts.config).toBe('path/to/config.ts')
    expect(opts.passthrough).toEqual([])
  })

  test('parses -c shorthand', () => {
    const opts = parseRunArgs(['-c', 'config.ts'])
    expect(opts.config).toBe('config.ts')
  })

  test('captures passthrough args', () => {
    const opts = parseRunArgs(['--config', 'config.ts', '--tags', '@smoke', '--format', 'progress'])
    expect(opts.config).toBe('config.ts')
    expect(opts.passthrough).toEqual(['--tags', '@smoke', '--format', 'progress'])
  })

  test('throws when --config is missing', () => {
    expect(() => parseRunArgs([])).toThrow('Missing required argument: --config')
  })

  test('throws when --config has no value', () => {
    expect(() => parseRunArgs(['--config'])).toThrow('Missing required argument: --config')
  })

  test('passthrough args before --config are captured', () => {
    const opts = parseRunArgs(['--tags', '@wip', '--config', 'config.ts'])
    expect(opts.config).toBe('config.ts')
    expect(opts.passthrough).toEqual(['--tags', '@wip'])
  })
})

describe('buildCucumberArgs', () => {
  const baseOptions = {
    configDir: '/project/test/bdd',
    setupPath: '/tmp/setup.ts',
    stepsImport: '/tools/exo-bdd/src/interface/steps/index.ts',
    passthrough: [] as string[],
  }

  test('resolves single features path relative to config dir', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
    })

    expect(args).toContain(resolve('/project/test/bdd', './features/**/*.feature'))
  })

  test('resolves multiple features paths', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: ['./features/**/*.feature', './extra/**/*.feature'],
    })

    expect(args).toContain(resolve('/project/test/bdd', './features/**/*.feature'))
    expect(args).toContain(resolve('/project/test/bdd', './extra/**/*.feature'))
  })

  test('includes setup import', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
    })

    const importIdx = args.indexOf('--import')
    expect(importIdx).toBeGreaterThanOrEqual(0)
    expect(args[importIdx + 1]).toBe('/tmp/setup.ts')
  })

  test('includes steps import', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
    })

    // Find the second --import
    const firstImportIdx = args.indexOf('--import')
    const secondImportIdx = args.indexOf('--import', firstImportIdx + 1)
    expect(secondImportIdx).toBeGreaterThan(firstImportIdx)
    expect(args[secondImportIdx + 1]).toBe('/tools/exo-bdd/src/interface/steps/index.ts')
  })

  test('appends passthrough args', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
      passthrough: ['--tags', '@smoke', '--format', 'progress'],
    })

    expect(args).toContain('--tags')
    expect(args).toContain('@smoke')
    expect(args).toContain('--format')
    expect(args).toContain('progress')
  })

  test('passthrough args come after imports', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
      passthrough: ['--tags', '@smoke'],
    })

    const lastImportIdx = args.lastIndexOf('--import')
    const tagsIdx = args.indexOf('--tags')
    expect(tagsIdx).toBeGreaterThan(lastImportIdx)
  })
})

describe('generateSetupContent', () => {
  test('generates valid setup code', () => {
    const content = generateSetupContent('/project/bdd/exo-bdd-test.config.ts', '/tools/exo-bdd')

    expect(content).toContain('setWorldConstructor(TestWorld)')
    expect(content).toContain('BeforeAll')
    expect(content).toContain('createAdapters')
    expect(content).toContain('Before')
    expect(content).toContain('AfterAll')
    expect(content).toContain('adapters?.dispose()')
  })

  test('imports config via file URL', () => {
    const content = generateSetupContent('/project/bdd/exo-bdd-test.config.ts', '/tools/exo-bdd')

    expect(content).toContain('file:///')
    expect(content).toContain('exo-bdd-test.config.ts')
  })

  test('imports exo-bdd modules from the provided root', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd')

    expect(content).toContain('application/config/index.ts')
    expect(content).toContain('infrastructure/factories/index.ts')
    expect(content).toContain('interface/world/index.ts')
  })

  test('attaches adapters to world in Before hook', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd')

    expect(content).toContain('adapters.http')
    expect(content).toContain('adapters.browser')
    expect(content).toContain('adapters.cli')
    expect(content).toContain('adapters.graph')
    expect(content).toContain('adapters.security')
  })

  test('handles screenshot capture on failure', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd')

    expect(content).toContain('Status.FAILED')
    expect(content).toContain('browser.screenshot()')
  })

  test('uses hasBrowser guard instead of direct getter access in After hook', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd')

    expect(content).toContain('this.hasBrowser')
  })
})
