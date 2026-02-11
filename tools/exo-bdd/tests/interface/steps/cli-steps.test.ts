import { test, expect, describe, beforeEach, mock } from 'bun:test'

// Mock Cucumber so importing step files doesn't trigger registration side-effects
const noop = () => {}
mock.module('@cucumber/cucumber', () => ({
  Given: noop,
  When: noop,
  Then: noop,
}))

// Mock @playwright/test so assertion handlers use bun:test's expect
mock.module('@playwright/test', () => ({ expect }))

import { VariableService } from '../../../src/application/services/VariableService.ts'
import { InterpolationService } from '../../../src/application/services/InterpolationService.ts'

// Step definition handlers – dynamic imports to ensure mocks are applied first
const { setEnvVar, setEnvVarsFromTable, setWorkingDir } = await import(
  '../../../src/interface/steps/cli/environment.steps.ts'
)
const { runCommand, runCommandWithStdin } = await import(
  '../../../src/interface/steps/cli/execution.steps.ts'
)
const {
  assertExitCode,
  assertExitCodeNot,
  assertCommandSucceeded,
  assertCommandFailed,
  assertStdoutContains,
  assertStdoutNotContains,
  assertStdoutMatches,
  assertStderrContains,
  assertStderrNotContains,
  assertStderrEmpty,
  assertStdoutEquals,
  storeStdout,
  storeStderr,
  storeExitCode,
} = await import('../../../src/interface/steps/cli/assertions.steps.ts')

// ---------------------------------------------------------------------------
// Helpers: mock world & mock CLI adapter
// ---------------------------------------------------------------------------

interface MockCliState {
  stdout: string
  stderr: string
  exitCode: number
  duration: number
}

function createMockCli(state: MockCliState = { stdout: '', stderr: '', exitCode: 0, duration: 100 }) {
  const result = {
    stdout: state.stdout,
    stderr: state.stderr,
    exitCode: state.exitCode,
    duration: state.duration,
  }

  const cli = {
    config: {} as any,

    // Environment
    setEnv: mock((_name: string, _value: string) => cli),
    setEnvs: mock((_env: Record<string, string>) => cli),
    clearEnv: mock((_name: string) => cli),
    setWorkingDir: mock((_dir: string) => cli),

    // Execution
    run: mock((_command: string) => Promise.resolve(result)),
    runWithStdin: mock((_command: string, _stdin: string) => Promise.resolve(result)),
    runWithTimeout: mock((_command: string, _timeoutMs: number) => Promise.resolve(result)),

    // Result accessors (read from mutable state)
    get result() { return result },
    get stdout() { return state.stdout },
    get stderr() { return state.stderr },
    get exitCode() { return state.exitCode },
    get duration() { return state.duration },

    // Utilities
    stdoutLine: mock((lineNumber: number) => {
      const lines = state.stdout.split('\n')
      return lines[lineNumber - 1] ?? ''
    }),
    stdoutMatching: mock((pattern: RegExp) => {
      const match = state.stdout.match(pattern)
      return match ? match[0] : null
    }),

    // Lifecycle
    dispose: mock(() => Promise.resolve()),

    // Allow tests to update state
    _setState(newState: Partial<MockCliState>) {
      Object.assign(state, newState)
      Object.assign(result, newState)
    },
  }

  return cli
}

interface MockWorld {
  cli: ReturnType<typeof createMockCli>
  interpolate: (text: string) => string
  setVariable: (name: string, value: unknown) => void
  getVariable: <T>(name: string) => T
  hasVariable: (name: string) => boolean
}

function createMockWorld(cliState?: MockCliState): MockWorld {
  const variableService = new VariableService()
  const interpolationService = new InterpolationService(variableService)

  return {
    cli: createMockCli(cliState),
    interpolate: (text: string) => interpolationService.interpolate(text),
    setVariable: (name: string, value: unknown) => variableService.set(name, value),
    getVariable: <T>(name: string) => variableService.get<T>(name),
    hasVariable: (name: string) => variableService.has(name),
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('CLI step definitions – Environment', () => {
  let world: MockWorld

  beforeEach(() => {
    world = createMockWorld()
  })

  // 1. 'I set env to' calls cli.setEnv
  test('I set environment variable {string} to {string} calls cli.setEnv', () => {
    const name = 'API_KEY'
    const value = 'secret123'

    setEnvVar(world, name, value)

    expect(world.cli.setEnv).toHaveBeenCalledTimes(1)
    expect(world.cli.setEnv).toHaveBeenCalledWith('API_KEY', 'secret123')
  })

  // 2. 'I set the following environment variables:' sets multiple
  test('I set the following environment variables sets multiple via setEnv', () => {
    const env: Record<string, string> = {
      NODE_ENV: 'test',
      PORT: '3000',
      DEBUG: 'true',
    }

    // Simulate a Cucumber DataTable with rowsHash()
    const dataTable = { rowsHash: () => env }
    setEnvVarsFromTable(world, dataTable)

    expect(world.cli.setEnv).toHaveBeenCalledTimes(3)
    expect(world.cli.setEnv).toHaveBeenCalledWith('NODE_ENV', 'test')
    expect(world.cli.setEnv).toHaveBeenCalledWith('PORT', '3000')
    expect(world.cli.setEnv).toHaveBeenCalledWith('DEBUG', 'true')
  })

  // 3. 'I set working directory to' calls cli.setWorkingDir
  test('I set working directory to {string} calls cli.setWorkingDir', () => {
    const dir = '/tmp/test-workspace'

    setWorkingDir(world, dir)

    expect(world.cli.setWorkingDir).toHaveBeenCalledTimes(1)
    expect(world.cli.setWorkingDir).toHaveBeenCalledWith('/tmp/test-workspace')
  })
})

describe('CLI step definitions – Execution', () => {
  let world: MockWorld

  beforeEach(() => {
    world = createMockWorld()
  })

  // 4. 'I run' calls cli.run with interpolated command
  test('I run {string} calls cli.run with interpolated command', async () => {
    const command = 'echo hello'

    await runCommand(world, command)

    expect(world.cli.run).toHaveBeenCalledTimes(1)
    expect(world.cli.run).toHaveBeenCalledWith('echo hello')
  })

  // 5. 'I run with stdin:' (docstring) calls cli.runWithStdin
  test('I run {string} with stdin: (docstring) calls cli.runWithStdin', async () => {
    const command = 'cat'
    const docString = 'line1\nline2\nline3'

    await runCommandWithStdin(world, command, docString)

    expect(world.cli.runWithStdin).toHaveBeenCalledTimes(1)
    expect(world.cli.runWithStdin).toHaveBeenCalledWith('cat', 'line1\nline2\nline3')
  })

  // 6. 'I run with stdin' (inline) calls cli.runWithStdin
  test('I run {string} with stdin {string} (inline) calls cli.runWithStdin', async () => {
    const command = 'grep pattern'
    const stdin = 'some input text'

    await runCommandWithStdin(world, command, stdin)

    expect(world.cli.runWithStdin).toHaveBeenCalledTimes(1)
    expect(world.cli.runWithStdin).toHaveBeenCalledWith('grep pattern', 'some input text')
  })
})

describe('CLI step definitions – Assertions', () => {
  // 7. 'exit code should be' passes for matching
  test('the exit code should be {int} passes for matching code', () => {
    const world = createMockWorld({ stdout: '', stderr: '', exitCode: 0, duration: 50 })

    assertExitCode(world, 0)
  })

  // 8. 'exit code should be' fails for mismatched
  test('the exit code should be {int} fails for mismatched code', () => {
    const world = createMockWorld({ stdout: '', stderr: '', exitCode: 1, duration: 50 })

    assertExitCodeNot(world, 0)
    expect(() => {
      assertExitCode(world, 0)
    }).toThrow()
  })

  // 9. 'exit code should not be' passes for different
  test('the exit code should not be {int} passes for different code', () => {
    const world = createMockWorld({ stdout: '', stderr: '', exitCode: 1, duration: 50 })

    assertExitCodeNot(world, 0)
  })

  // 10. 'command should succeed' passes for exit code 0
  test('the command should succeed passes for exit code 0', () => {
    const world = createMockWorld({ stdout: 'ok', stderr: '', exitCode: 0, duration: 50 })

    assertCommandSucceeded(world)
  })

  // 11. 'command should fail' passes for non-zero exit code
  test('the command should fail passes for non-zero exit code', () => {
    const world = createMockWorld({ stdout: '', stderr: 'error', exitCode: 1, duration: 50 })

    assertCommandFailed(world)
  })

  // 12. 'stdout should contain' passes for substring
  test('stdout should contain {string} passes for substring', () => {
    const world = createMockWorld({
      stdout: 'Hello World from CLI',
      stderr: '',
      exitCode: 0,
      duration: 50,
    })

    assertStdoutContains(world, 'Hello World')
  })

  // 13. 'stdout should not contain' passes
  test('stdout should not contain {string} passes when absent', () => {
    const world = createMockWorld({
      stdout: 'Hello World',
      stderr: '',
      exitCode: 0,
      duration: 50,
    })

    assertStdoutNotContains(world, 'Goodbye')
  })

  // 14. 'stdout should match' passes for regex match
  test('stdout should match {string} passes for regex pattern', () => {
    const world = createMockWorld({
      stdout: 'version 3.14.2',
      stderr: '',
      exitCode: 0,
      duration: 50,
    })

    assertStdoutMatches(world, 'version \\d+\\.\\d+\\.\\d+')
  })

  // 15. 'stderr should contain' passes for substring
  test('stderr should contain {string} passes for substring', () => {
    const world = createMockWorld({
      stdout: '',
      stderr: 'Warning: deprecated function used',
      exitCode: 0,
      duration: 50,
    })

    assertStderrContains(world, 'deprecated')
  })

  // 16. 'stderr should not contain' passes
  test('stderr should not contain {string} passes when absent', () => {
    const world = createMockWorld({
      stdout: '',
      stderr: 'Warning: deprecated',
      exitCode: 0,
      duration: 50,
    })

    assertStderrNotContains(world, 'fatal')
  })

  // 17. 'stderr should be empty' passes when blank
  test('stderr should be empty passes when stderr is blank', () => {
    const world = createMockWorld({
      stdout: 'output',
      stderr: '',
      exitCode: 0,
      duration: 50,
    })

    assertStderrEmpty(world)
  })

  test('stderr should be empty passes when stderr is only whitespace', () => {
    const world = createMockWorld({
      stdout: 'output',
      stderr: '   \n  ',
      exitCode: 0,
      duration: 50,
    })

    assertStderrEmpty(world)
  })

  // 18. 'stdout should equal:' (docstring) passes for exact match
  test('stdout should equal: (docstring) passes for exact trimmed match', () => {
    const world = createMockWorld({
      stdout: '  Hello World  ',
      stderr: '',
      exitCode: 0,
      duration: 50,
    })

    assertStdoutEquals(world, '  Hello World  ')
  })

  // 19. 'I store stdout as' stores trimmed stdout
  test('I store stdout as {string} stores trimmed stdout', () => {
    const world = createMockWorld({
      stdout: '  result-value  \n',
      stderr: '',
      exitCode: 0,
      duration: 50,
    })

    storeStdout(world, 'output')

    expect(world.getVariable<string>('output')).toBe('result-value')
  })

  // 20. 'I store stderr as' stores trimmed stderr
  test('I store stderr as {string} stores trimmed stderr', () => {
    const world = createMockWorld({
      stdout: '',
      stderr: '  warning message  \n',
      exitCode: 0,
      duration: 50,
    })

    storeStderr(world, 'errorOutput')

    expect(world.getVariable<string>('errorOutput')).toBe('warning message')
  })

  // 21. 'I store exit code as' stores exit code number
  test('I store exit code as {string} stores exit code as number', () => {
    const world = createMockWorld({
      stdout: '',
      stderr: '',
      exitCode: 42,
      duration: 50,
    })

    storeExitCode(world, 'code')

    expect(world.getVariable<number>('code')).toBe(42)
  })
})

describe('CLI step definitions – Variable interpolation integration', () => {
  test('run command with interpolated variable in command string', async () => {
    const world = createMockWorld()
    world.setVariable('script', 'build.sh')

    await world.cli.run(world.interpolate('bash ${script}'))

    expect(world.cli.run).toHaveBeenCalledWith('bash build.sh')
  })

  test('setEnv with interpolated value from variable', () => {
    const world = createMockWorld()
    world.setVariable('port', '8080')

    world.cli.setEnv('PORT', world.interpolate('${port}'))

    expect(world.cli.setEnv).toHaveBeenCalledWith('PORT', '8080')
  })

  test('setWorkingDir with interpolated path', () => {
    const world = createMockWorld()
    world.setVariable('project', 'my-app')

    world.cli.setWorkingDir(world.interpolate('/home/user/${project}'))

    expect(world.cli.setWorkingDir).toHaveBeenCalledWith('/home/user/my-app')
  })

  test('runWithStdin with interpolated command and stdin', async () => {
    const world = createMockWorld()
    world.setVariable('tool', 'jq')
    world.setVariable('data', '{"key":"value"}')

    await world.cli.runWithStdin(
      world.interpolate('${tool} .key'),
      world.interpolate('${data}'),
    )

    expect(world.cli.runWithStdin).toHaveBeenCalledWith('jq .key', '{"key":"value"}')
  })

  test('stdout assertion with interpolated expected string', () => {
    const world = createMockWorld({
      stdout: 'Hello Alice',
      stderr: '',
      exitCode: 0,
      duration: 50,
    })
    world.setVariable('name', 'Alice')

    expect(world.cli.stdout).toContain(world.interpolate('Hello ${name}'))
  })

  test('stored output can be used in subsequent interpolation', async () => {
    const world = createMockWorld({
      stdout: '  token-abc123  \n',
      stderr: '',
      exitCode: 0,
      duration: 50,
    })

    // Step 1: store stdout
    world.setVariable('token', world.cli.stdout.trim())
    expect(world.getVariable<string>('token')).toBe('token-abc123')

    // Step 2: use stored variable in a subsequent command
    await world.cli.run(world.interpolate('curl -H "Authorization: ${token}" /api'))

    expect(world.cli.run).toHaveBeenCalledWith('curl -H "Authorization: token-abc123" /api')
  })
})
