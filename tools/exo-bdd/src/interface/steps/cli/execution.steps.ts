import { When } from '@cucumber/cucumber'
import { TestWorld } from '../../world/index.ts'

export interface ExecutionContext {
  cli: {
    run(command: string): Promise<unknown>
    runWithStdin(command: string, stdin: string): Promise<unknown>
    runWithTimeout(command: string, timeoutMs: number): Promise<unknown>
  }
  interpolate(value: string): string
}

export async function runCommand(context: ExecutionContext, command: string): Promise<void> {
  await context.cli.run(context.interpolate(command))
}

export async function runCommandWithStdin(context: ExecutionContext, command: string, stdin: string): Promise<void> {
  await context.cli.runWithStdin(context.interpolate(command), context.interpolate(stdin))
}

export async function runCommandWithTimeout(context: ExecutionContext, command: string, timeout: number): Promise<void> {
  await context.cli.runWithTimeout(context.interpolate(command), timeout * 1000)
}

When<TestWorld>('I run {string}', async function (command: string) {
  await runCommand(this, command)
})

When<TestWorld>(
  'I run {string} with stdin:',
  async function (command: string, docString: string) {
    await runCommandWithStdin(this, command, docString)
  },
)

When<TestWorld>(
  'I run {string} with stdin {string}',
  async function (command: string, stdin: string) {
    await runCommandWithStdin(this, command, stdin)
  },
)

When<TestWorld>(
  'I run {string} with timeout {int} seconds',
  async function (command: string, timeout: number) {
    await runCommandWithTimeout(this, command, timeout)
  },
)
