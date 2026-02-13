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

  test('injects baseUrl variable when http adapter has baseURL', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd', {
      adapters: {
        http: { baseURL: 'http://localhost:4005/api' },
      },
    })

    expect(content).toContain("this.setVariable('baseUrl', 'http://localhost:4005/api')")
  })

  test('injects browserBaseUrl variable when browser adapter has baseURL', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd', {
      adapters: {
        http: { baseURL: 'http://localhost:4005' },
        browser: { baseURL: 'http://localhost:4002' },
      },
    })

    expect(content).toContain("this.setVariable('baseUrl', 'http://localhost:4005')")
    expect(content).toContain("this.setVariable('browserBaseUrl', 'http://localhost:4002')")
  })

  test('uses browser baseURL as baseUrl when no http adapter configured', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd', {
      adapters: {
        browser: { baseURL: 'http://localhost:4002' },
      },
    })

    expect(content).toContain("this.setVariable('baseUrl', 'http://localhost:4002')")
    expect(content).toContain("this.setVariable('browserBaseUrl', 'http://localhost:4002')")
  })

  test('does not inject baseUrl when no http or browser adapter configured', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd', {
      adapters: {
        cli: { workingDir: '/tmp' },
      },
    })

    expect(content).not.toContain("setVariable('baseUrl'")
    expect(content).not.toContain("setVariable('browserBaseUrl'")
  })

  test('does not inject baseUrl when config is not provided', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd')

    expect(content).not.toContain("setVariable('baseUrl'")
  })

  test('marks injections with comment', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd', {
      adapters: {
        http: { baseURL: 'http://localhost:4005' },
      },
    })

    expect(content).toContain('Auto-injected from config')
  })

  test('injects user-defined variables from config', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd', {
      adapters: {},
      variables: {
        'api-token': 'secret-token-123',
        'workspace-slug': 'my-workspace',
      },
    })

    expect(content).toContain("this.setVariable('api-token', 'secret-token-123')")
    expect(content).toContain("this.setVariable('workspace-slug', 'my-workspace')")
  })

  test('injects variables alongside baseUrl', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd', {
      adapters: {
        http: { baseURL: 'http://localhost:4005' },
      },
      variables: {
        'my-token': 'tok_abc',
      },
    })

    expect(content).toContain("this.setVariable('baseUrl', 'http://localhost:4005')")
    expect(content).toContain("this.setVariable('my-token', 'tok_abc')")
  })

  test('does not inject variables when variables is empty', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd', {
      adapters: {},
      variables: {},
    })

    // No injection comment should appear since no variables and no adapters
    expect(content).not.toContain('Auto-injected')
  })

  test('does not inject variables when variables is undefined', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd', {
      adapters: {},
    })

    expect(content).not.toContain('Auto-injected')
  })

  test('escapes single quotes in variable values', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd', {
      adapters: {},
      variables: {
        'msg': "it's a test",
      },
    })

    expect(content).toContain("this.setVariable('msg', 'it\\'s a test')")
  })

  test('emits setDefaultTimeout when timeout is configured', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd', {
      adapters: {},
      timeout: 300000,
    })

    expect(content).toContain('setDefaultTimeout(300000)')
    expect(content).toContain('import { BeforeAll, AfterAll, Before, After, setWorldConstructor, setDefaultTimeout, Status }')
  })

  test('does not emit setDefaultTimeout when timeout is not configured', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd', {
      adapters: {},
    })

    expect(content).not.toContain('setDefaultTimeout(')
  })

  test('always imports setDefaultTimeout (available if needed)', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd')

    expect(content).toContain('setDefaultTimeout')
  })
})
