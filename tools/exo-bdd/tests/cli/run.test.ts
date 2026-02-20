import { test, expect, describe } from 'bun:test'
import { resolve } from 'node:path'
import { parseRunArgs, buildCucumberArgs, buildMessageFormatterArgs, extractConfigName, generateSetupContent, mergeTags, filterFeaturesByAdapter } from '../../src/cli/run.ts'
import type { ReportConfig } from '../../src/application/config/ConfigSchema.ts'

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

  test('parses --tags flag', () => {
    const opts = parseRunArgs(['--config', 'config.ts', '--tags', '@smoke'])
    expect(opts.config).toBe('config.ts')
    expect(opts.tags).toBe('@smoke')
    expect(opts.passthrough).toEqual([])
  })

  test('parses -t shorthand for tags', () => {
    const opts = parseRunArgs(['-c', 'config.ts', '-t', 'not @slow'])
    expect(opts.tags).toBe('not @slow')
  })

  test('captures other passthrough args but extracts --tags', () => {
    const opts = parseRunArgs(['--config', 'config.ts', '--tags', '@smoke', '--format', 'progress'])
    expect(opts.config).toBe('config.ts')
    expect(opts.tags).toBe('@smoke')
    expect(opts.passthrough).toEqual(['--format', 'progress'])
  })

  test('throws when --config is missing', () => {
    expect(() => parseRunArgs([])).toThrow('Missing required argument: --config')
  })

  test('throws when --config has no value', () => {
    expect(() => parseRunArgs(['--config'])).toThrow('Missing required argument: --config')
  })

  test('tags is undefined when not provided', () => {
    const opts = parseRunArgs(['--config', 'config.ts'])
    expect(opts.tags).toBeUndefined()
  })

  test('passthrough args exclude parsed flags', () => {
    const opts = parseRunArgs(['--format', 'progress', '--config', 'config.ts', '--tags', '@api'])
    expect(opts.config).toBe('config.ts')
    expect(opts.tags).toBe('@api')
    expect(opts.passthrough).toEqual(['--format', 'progress'])
  })

  test('parses --adapter flag', () => {
    const opts = parseRunArgs(['--config', 'config.ts', '--adapter', 'browser'])
    expect(opts.adapter).toBe('browser')
  })

  test('parses -a shorthand for adapter', () => {
    const opts = parseRunArgs(['-c', 'config.ts', '-a', 'security'])
    expect(opts.adapter).toBe('security')
  })

  test('adapter is undefined when not provided', () => {
    const opts = parseRunArgs(['--config', 'config.ts'])
    expect(opts.adapter).toBeUndefined()
  })

  test('parses all flags together', () => {
    const opts = parseRunArgs(['-c', 'config.ts', '-t', '@smoke', '-a', 'http', '--format', 'progress'])
    expect(opts.config).toBe('config.ts')
    expect(opts.tags).toBe('@smoke')
    expect(opts.adapter).toBe('http')
    expect(opts.passthrough).toEqual(['--format', 'progress'])
  })

  test('parses --no-retry flag', () => {
    const opts = parseRunArgs(['--config', 'config.ts', '--no-retry'])
    expect(opts.noRetry).toBe(true)
  })

  test('noRetry defaults to false when not provided', () => {
    const opts = parseRunArgs(['--config', 'config.ts'])
    expect(opts.noRetry).toBe(false)
  })

  test('parses --no-retry with other flags', () => {
    const opts = parseRunArgs(['-c', 'config.ts', '-t', '@smoke', '--no-retry', '-a', 'http'])
    expect(opts.config).toBe('config.ts')
    expect(opts.tags).toBe('@smoke')
    expect(opts.adapter).toBe('http')
    expect(opts.noRetry).toBe(true)
    expect(opts.passthrough).toEqual([])
  })
})

describe('filterFeaturesByAdapter', () => {
  test('keeps globs that already match the adapter suffix', () => {
    const result = filterFeaturesByAdapter('./features/**/*.browser.feature', 'browser')
    expect(result).toEqual(['./features/**/*.browser.feature'])
  })

  test('rewrites generic globs to target the adapter', () => {
    const result = filterFeaturesByAdapter('./features/**/*.feature', 'browser')
    expect(result).toEqual(['./features/**/*.browser.feature'])
  })

  test('drops globs for a different adapter', () => {
    const result = filterFeaturesByAdapter('./features/**/*.security.feature', 'browser')
    expect(result).toEqual([])
  })

  test('handles array of mixed globs', () => {
    const result = filterFeaturesByAdapter(
      ['./features/**/*.browser.feature', './features/**/*.security.feature'],
      'browser',
    )
    expect(result).toEqual(['./features/**/*.browser.feature'])
  })

  test('rewrites generic and keeps matching in mixed array', () => {
    const result = filterFeaturesByAdapter(
      ['./features/**/*.feature', './features/**/*.security.feature'],
      'browser',
    )
    expect(result).toEqual(['./features/**/*.browser.feature'])
  })

  test('works with security adapter', () => {
    const result = filterFeaturesByAdapter(
      ['./features/**/*.browser.feature', './features/**/*.security.feature'],
      'security',
    )
    expect(result).toEqual(['./features/**/*.security.feature'])
  })

  test('works with cli adapter', () => {
    const result = filterFeaturesByAdapter('./features/**/*.feature', 'cli')
    expect(result).toEqual(['./features/**/*.cli.feature'])
  })

  test('preserves non-feature patterns as-is', () => {
    const result = filterFeaturesByAdapter('./some/path', 'browser')
    expect(result).toEqual(['./some/path'])
  })
})

describe('mergeTags', () => {
  test('returns undefined when both are undefined', () => {
    expect(mergeTags(undefined, undefined)).toBeUndefined()
  })

  test('returns config tags when CLI tags is undefined', () => {
    expect(mergeTags('not @neo4j', undefined)).toBe('not @neo4j')
  })

  test('returns CLI tags when config tags is undefined', () => {
    expect(mergeTags(undefined, '@smoke')).toBe('@smoke')
  })

  test('ANDs config and CLI tags with parentheses', () => {
    expect(mergeTags('not @neo4j', '@smoke')).toBe('(not @neo4j) and (@smoke)')
  })

  test('handles complex tag expressions', () => {
    expect(mergeTags('not @neo4j and not @slow', 'not @security')).toBe('(not @neo4j and not @slow) and (not @security)')
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
      passthrough: ['--format', 'progress'],
    })

    expect(args).toContain('--format')
    expect(args).toContain('progress')
  })

  test('passthrough args come after imports', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
      passthrough: ['--format', 'progress'],
    })

    const lastImportIdx = args.lastIndexOf('--import')
    const formatIdx = args.indexOf('--format')
    expect(formatIdx).toBeGreaterThan(lastImportIdx)
  })

  test('includes --tags from config tags option', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
      tags: 'not @neo4j',
    })

    const tagsIdx = args.indexOf('--tags')
    expect(tagsIdx).toBeGreaterThanOrEqual(0)
    expect(args[tagsIdx + 1]).toBe('not @neo4j')
  })

  test('config tags come before passthrough args', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
      tags: 'not @neo4j',
      passthrough: ['--format', 'progress'],
    })

    const tagsIdx = args.indexOf('--tags')
    const formatIdx = args.indexOf('--format')
    expect(tagsIdx).toBeLessThan(formatIdx)
  })

  test('omits --tags when tags is undefined', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
    })

    expect(args).not.toContain('--tags')
  })

  test('includes --retry 0 when noRetry is true', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
      noRetry: true,
    })

    const retryIdx = args.indexOf('--retry')
    expect(retryIdx).toBeGreaterThanOrEqual(0)
    expect(args[retryIdx + 1]).toBe('0')
  })

  test('omits --retry when noRetry is false', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
      noRetry: false,
    })

    expect(args).not.toContain('--retry')
  })

  test('omits --retry when noRetry is undefined', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
    })

    expect(args).not.toContain('--retry')
  })

  test('includes --format message:<path> when report.message is true', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
      report: { message: true },
      configName: 'identity',
    })

    const formatIdx = args.indexOf('--format')
    expect(formatIdx).toBeGreaterThanOrEqual(0)
    const formatValue = args[formatIdx + 1]!
    expect(formatValue).toMatch(/^message:/)
    expect(formatValue).toMatch(/\.exo-bdd-reports\/identity-.*\.ndjson$/)
  })

  test('uses custom outputDir when report.message is an object', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
      report: { message: { outputDir: '/tmp/custom-reports' } },
      configName: 'identity',
    })

    const formatIdx = args.indexOf('--format')
    expect(formatIdx).toBeGreaterThanOrEqual(0)
    const formatValue = args[formatIdx + 1]!
    expect(formatValue).toMatch(/^message:\/tmp\/custom-reports\/identity-.*\.ndjson$/)
  })

  test('does not include --format message when report.message is false', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
      report: { message: false },
    })

    const formatArgs = args.filter((_, i) => args[i - 1] === '--format')
    const messageFormatArgs = formatArgs.filter((v) => v?.startsWith('message:'))
    expect(messageFormatArgs).toHaveLength(0)
  })

  test('does not include --format message when report is undefined', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
    })

    const formatArgs = args.filter((_, i) => args[i - 1] === '--format')
    const messageFormatArgs = formatArgs.filter((v) => v?.startsWith('message:'))
    expect(messageFormatArgs).toHaveLength(0)
  })

  test('does not include --format message when report.message is undefined', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
      report: {},
    })

    const formatArgs = args.filter((_, i) => args[i - 1] === '--format')
    const messageFormatArgs = formatArgs.filter((v) => v?.startsWith('message:'))
    expect(messageFormatArgs).toHaveLength(0)
  })

  test('message formatter coexists with tags and other args', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
      tags: '@smoke',
      noRetry: true,
      passthrough: ['--format', 'progress'],
      report: { message: true },
      configName: 'jarga',
    })

    // Tags are present
    expect(args).toContain('--tags')
    expect(args).toContain('@smoke')
    // Retry arg is present
    expect(args).toContain('--retry')
    // Passthrough format is present
    expect(args).toContain('progress')
    // Message format is also present
    const formatIndices = args.reduce<number[]>((acc, v, i) => {
      if (v === '--format') acc.push(i)
      return acc
    }, [])
    expect(formatIndices.length).toBeGreaterThanOrEqual(2)
    const hasMessageFormat = formatIndices.some((i) => args[i + 1]?.startsWith('message:'))
    expect(hasMessageFormat).toBe(true)
  })

  test('uses "unknown" as config name when configName is not provided', () => {
    const args = buildCucumberArgs({
      ...baseOptions,
      features: './features/**/*.feature',
      report: { message: true },
    })

    const formatIdx = args.indexOf('--format')
    const formatValue = args[formatIdx + 1]!
    expect(formatValue).toMatch(/\.exo-bdd-reports\/unknown-.*\.ndjson$/)
  })
})

describe('buildMessageFormatterArgs', () => {
  test('returns empty array when report is undefined', () => {
    const args = buildMessageFormatterArgs(undefined, 'test-config')
    expect(args).toEqual([])
  })

  test('returns empty array when report.message is undefined', () => {
    const args = buildMessageFormatterArgs({}, 'test-config')
    expect(args).toEqual([])
  })

  test('returns empty array when report.message is false', () => {
    const args = buildMessageFormatterArgs({ message: false }, 'test-config')
    expect(args).toEqual([])
  })

  test('returns --format and message:<default-path> when report.message is true', () => {
    const args = buildMessageFormatterArgs({ message: true }, 'identity')
    expect(args).toHaveLength(2)
    expect(args[0]).toBe('--format')
    expect(args[1]).toMatch(/^message:\.exo-bdd-reports\/identity-\d{4}-\d{2}-\d{2}T.*\.ndjson$/)
  })

  test('uses custom outputDir when report.message is an object', () => {
    const args = buildMessageFormatterArgs({ message: { outputDir: '/tmp/out' } }, 'jarga')
    expect(args).toHaveLength(2)
    expect(args[0]).toBe('--format')
    expect(args[1]).toMatch(/^message:\/tmp\/out\/jarga-\d{4}-\d{2}-\d{2}T.*\.ndjson$/)
  })

  test('generates ISO timestamp in filename', () => {
    const args = buildMessageFormatterArgs({ message: true }, 'test')
    const path = args[1]!.replace('message:', '')
    const filename = path.split('/').pop()!
    // Filename should be like: test-2026-02-20T12-30-45.123Z.ndjson
    expect(filename).toMatch(/^test-\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}\.\d{3}Z\.ndjson$/)
  })

  test('uses "unknown" config name when not provided', () => {
    const args = buildMessageFormatterArgs({ message: true })
    expect(args[1]).toMatch(/^message:\.exo-bdd-reports\/unknown-/)
  })
})

describe('extractConfigName', () => {
  test('extracts name from exo-bdd-<name>.config.ts pattern', () => {
    expect(extractConfigName('/project/bdd/exo-bdd-identity.config.ts')).toBe('identity')
  })

  test('extracts name from exo-bdd-<name>.config.ts with hyphenated name', () => {
    expect(extractConfigName('/project/bdd/exo-bdd-jarga-web.config.ts')).toBe('jarga-web')
  })

  test('extracts name from plain config filename', () => {
    expect(extractConfigName('/project/bdd/my-app.config.ts')).toBe('my-app')
  })

  test('strips .config.ts suffix', () => {
    expect(extractConfigName('/project/bdd/identity.config.ts')).toBe('identity')
  })

  test('returns basename without extension for non-standard names', () => {
    expect(extractConfigName('/project/bdd/config.ts')).toBe('config')
  })

  test('handles deeply nested paths', () => {
    expect(extractConfigName('/home/user/workspace/apps/identity/test/bdd/exo-bdd-identity.config.ts')).toBe('identity')
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
    expect(content).toContain('this.browser.screenshot(')
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

  test('passes adapterFilter to createAdapters when provided', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd', undefined, 'security')

    expect(content).toContain("createAdapters(config, { adapterFilter: 'security' })")
  })

  test('does not pass adapterFilter when not provided', () => {
    const content = generateSetupContent('/project/bdd/config.ts', '/tools/exo-bdd')

    expect(content).toContain('createAdapters(config)')
    expect(content).not.toContain('adapterFilter')
  })
})
