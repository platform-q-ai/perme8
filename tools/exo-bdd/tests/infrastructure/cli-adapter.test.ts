import { test, expect, describe } from 'bun:test'
import { BunCliAdapter } from '../../src/infrastructure/adapters/cli/BunCliAdapter.ts'

describe('BunCliAdapter', () => {
  test('run executes a command and captures stdout', async () => {
    const adapter = new BunCliAdapter({})
    const result = await adapter.run('echo "hello world"')
    expect(result.stdout.trim()).toBe('hello world')
    expect(result.exitCode).toBe(0)
  })

  test('run captures stderr', async () => {
    const adapter = new BunCliAdapter({})
    const result = await adapter.run('echo "error" >&2')
    expect(result.stderr.trim()).toBe('error')
  })

  test('run captures non-zero exit codes', async () => {
    const adapter = new BunCliAdapter({})
    const result = await adapter.run('exit 1')
    expect(result.exitCode).toBe(1)
  })

  test('run records duration', async () => {
    const adapter = new BunCliAdapter({})
    const result = await adapter.run('echo ok')
    expect(result.duration).toBeGreaterThanOrEqual(0)
  })

  test('setEnv sets environment variables', async () => {
    const adapter = new BunCliAdapter({})
    adapter.setEnv('MY_TEST_VAR', 'test_value')
    const result = await adapter.run('echo $MY_TEST_VAR')
    expect(result.stdout.trim()).toBe('test_value')
  })

  test('setWorkingDir changes working directory', async () => {
    const adapter = new BunCliAdapter({})
    adapter.setWorkingDir('/tmp')
    const result = await adapter.run('pwd')
    expect(result.stdout.trim()).toBe('/tmp')
  })

  test('result accessor returns last result', async () => {
    const adapter = new BunCliAdapter({})
    await adapter.run('echo "test"')
    expect(adapter.stdout.trim()).toBe('test')
    expect(adapter.exitCode).toBe(0)
  })

  test('runWithStdin sends stdin to command', async () => {
    const adapter = new BunCliAdapter({})
    const result = await adapter.runWithStdin('cat', 'hello from stdin')
    expect(result.stdout).toBe('hello from stdin')
  })

  test('chaining setEnv calls', async () => {
    const adapter = new BunCliAdapter({})
    adapter.setEnv('A', '1').setEnv('B', '2')
    const result = await adapter.run('echo "$A $B"')
    expect(result.stdout.trim()).toBe('1 2')
  })

  test('run with default config (no cwd, no env)', async () => {
    const adapter = new BunCliAdapter({})
    const result = await adapter.run('echo "default"')
    expect(result.stdout.trim()).toBe('default')
    expect(result.exitCode).toBe(0)
  })

  test('run with config-level env vars', async () => {
    const adapter = new BunCliAdapter({ env: { CONFIG_VAR: 'from_config' } })
    const result = await adapter.run('echo $CONFIG_VAR')
    expect(result.stdout.trim()).toBe('from_config')
  })

  test('run with config-level workingDir', async () => {
    const adapter = new BunCliAdapter({ workingDir: '/tmp' })
    const result = await adapter.run('pwd')
    expect(result.stdout.trim()).toBe('/tmp')
  })

  test('run command with quotes and special chars', async () => {
    const adapter = new BunCliAdapter({})
    const result = await adapter.run("echo \"hello 'world'\"")
    expect(result.stdout.trim()).toBe("hello 'world'")
  })

  test('run captures both stdout and stderr', async () => {
    const adapter = new BunCliAdapter({})
    const result = await adapter.run('echo "out" && echo "err" >&2')
    expect(result.stdout.trim()).toBe('out')
    expect(result.stderr.trim()).toBe('err')
  })

  test('result throws if accessed before any run', () => {
    const adapter = new BunCliAdapter({})
    expect(() => adapter.stdout).toThrow()
  })

  test('runWithStdin handles multiline input', async () => {
    const adapter = new BunCliAdapter({})
    const result = await adapter.runWithStdin('cat', 'line1\nline2\nline3')
    expect(result.stdout).toBe('line1\nline2\nline3')
  })

  test('runWithStdin with empty stdin', async () => {
    const adapter = new BunCliAdapter({})
    const result = await adapter.runWithStdin('cat', '')
    expect(result.stdout).toBe('')
  })

  test('setEnv overrides config-level env', async () => {
    const adapter = new BunCliAdapter({ env: { MY_VAR: 'original' } })
    adapter.setEnv('MY_VAR', 'override')
    const result = await adapter.run('echo $MY_VAR')
    expect(result.stdout.trim()).toBe('override')
  })

  test('setWorkingDir overrides config-level dir', async () => {
    const adapter = new BunCliAdapter({ workingDir: '/' })
    adapter.setWorkingDir('/tmp')
    const result = await adapter.run('pwd')
    expect(result.stdout.trim()).toBe('/tmp')
  })

  test('dispose is a no-op (does not throw)', async () => {
    const adapter = new BunCliAdapter({})
    await expect(adapter.dispose()).resolves.toBeUndefined()
  })

  test('long-running command captures correct duration', async () => {
    const adapter = new BunCliAdapter({})
    const result = await adapter.run('sleep 0.1 && echo done')
    expect(result.duration).toBeGreaterThanOrEqual(80)
    expect(result.stdout.trim()).toBe('done')
  })
})
