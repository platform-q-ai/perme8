import { test, expect, describe, beforeEach, afterEach } from 'bun:test'
import { resolve, join } from 'node:path'
import { existsSync, rmSync, readFileSync } from 'node:fs'
import { parseInitArgs, runInit, validateProjectName } from '../../src/cli/init.ts'
import { configFileName } from '../../src/cli/templates/config.ts'

const tmpDir = resolve(import.meta.dir, '../../.tmp-test-init')

describe('parseInitArgs', () => {
  test('parses --name flag', () => {
    const opts = parseInitArgs(['--name', 'jarga-web'])
    expect(opts.name).toBe('jarga-web')
    expect(opts.dir).toBeUndefined()
  })

  test('parses -n shorthand', () => {
    const opts = parseInitArgs(['-n', 'my-project'])
    expect(opts.name).toBe('my-project')
  })

  test('parses --dir flag', () => {
    const opts = parseInitArgs(['--name', 'jarga-web', '--dir', '/tmp/bdd'])
    expect(opts.name).toBe('jarga-web')
    expect(opts.dir).toBe('/tmp/bdd')
  })

  test('parses -d shorthand', () => {
    const opts = parseInitArgs(['-n', 'jarga-web', '-d', '/tmp/bdd'])
    expect(opts.name).toBe('jarga-web')
    expect(opts.dir).toBe('/tmp/bdd')
  })

  test('throws when --name is missing', () => {
    expect(() => parseInitArgs([])).toThrow('Missing required argument: --name')
  })

  test('throws when --name has no value', () => {
    expect(() => parseInitArgs(['--name'])).toThrow('Missing required argument: --name')
  })

  test('rejects names with path traversal', () => {
    expect(() => parseInitArgs(['--name', '../../etc/passwd'])).toThrow('Invalid project name')
  })

  test('rejects names with slashes', () => {
    expect(() => parseInitArgs(['--name', 'foo/bar'])).toThrow('Invalid project name')
  })

  test('rejects names starting with a dot', () => {
    expect(() => parseInitArgs(['--name', '.hidden'])).toThrow('Invalid project name')
  })
})

describe('validateProjectName', () => {
  test('accepts valid names', () => {
    expect(() => validateProjectName('jarga-web')).not.toThrow()
    expect(() => validateProjectName('my_project')).not.toThrow()
    expect(() => validateProjectName('app2')).not.toThrow()
    expect(() => validateProjectName('Project.Name')).not.toThrow()
  })

  test('rejects path traversal', () => {
    expect(() => validateProjectName('../../etc')).toThrow('Invalid project name')
  })

  test('rejects slashes', () => {
    expect(() => validateProjectName('foo/bar')).toThrow('Invalid project name')
  })

  test('rejects empty-like names', () => {
    expect(() => validateProjectName('-starts-with-dash')).toThrow('Invalid project name')
  })
})

describe('configFileName', () => {
  test('generates correct file name', () => {
    expect(configFileName('jarga-web')).toBe('exo-bdd-jarga-web.config.ts')
  })

  test('handles underscored names', () => {
    expect(configFileName('jarga_api')).toBe('exo-bdd-jarga_api.config.ts')
  })
})

describe('runInit', () => {
  beforeEach(() => {
    if (existsSync(tmpDir)) {
      rmSync(tmpDir, { recursive: true })
    }
  })

  afterEach(() => {
    if (existsSync(tmpDir)) {
      rmSync(tmpDir, { recursive: true })
    }
  })

  test('creates config file in target directory', async () => {
    const result = await runInit({ name: 'jarga-web', dir: tmpDir })

    expect(result.configPath).toBe(join(tmpDir, 'exo-bdd-jarga-web.config.ts'))
    expect(existsSync(result.configPath)).toBe(true)
  })

  test('creates features directory', async () => {
    const result = await runInit({ name: 'jarga-web', dir: tmpDir })

    expect(result.featuresDir).toBe(join(tmpDir, 'features'))
    expect(existsSync(result.featuresDir)).toBe(true)
  })

  test('generated config imports defineConfig', async () => {
    await runInit({ name: 'jarga-web', dir: tmpDir })

    const content = readFileSync(join(tmpDir, 'exo-bdd-jarga-web.config.ts'), 'utf-8')
    expect(content).toContain("import { defineConfig } from 'exo-bdd'")
  })

  test('generated config has features path', async () => {
    await runInit({ name: 'jarga-web', dir: tmpDir })

    const content = readFileSync(join(tmpDir, 'exo-bdd-jarga-web.config.ts'), 'utf-8')
    expect(content).toContain("features: './features/**/*.feature'")
  })

  test('generated config has adapters block with comments', async () => {
    await runInit({ name: 'jarga-web', dir: tmpDir })

    const content = readFileSync(join(tmpDir, 'exo-bdd-jarga-web.config.ts'), 'utf-8')
    expect(content).toContain('adapters: {')
    expect(content).toContain('// http:')
    expect(content).toContain('// browser:')
    expect(content).toContain('// cli:')
    expect(content).toContain('// graph:')
    expect(content).toContain('// security:')
  })

  test('throws if config already exists', async () => {
    await runInit({ name: 'jarga-web', dir: tmpDir })

    await expect(runInit({ name: 'jarga-web', dir: tmpDir })).rejects.toThrow(
      'Config file already exists'
    )
  })

  test('creates target directory if it does not exist', async () => {
    const nestedDir = join(tmpDir, 'nested', 'deep')
    expect(existsSync(nestedDir)).toBe(false)

    await runInit({ name: 'test-project', dir: nestedDir })

    expect(existsSync(nestedDir)).toBe(true)
    expect(existsSync(join(nestedDir, 'exo-bdd-test-project.config.ts'))).toBe(true)
  })
})
