import type { CommandResult } from '../../domain/entities/index.ts'
import type { CliAdapterConfig } from '../config/ConfigSchema.ts'

export interface CliPort {
  // Configuration
  readonly config: CliAdapterConfig

  // Environment
  setEnv(name: string, value: string): this
  setEnvs(env: Record<string, string>): this
  clearEnv(name: string): this
  setWorkingDir(dir: string): this

  // Execution
  run(command: string): Promise<CommandResult>
  runWithStdin(command: string, stdin: string): Promise<CommandResult>
  runWithTimeout(command: string, timeoutMs: number): Promise<CommandResult>

  // Result accessors (from last command)
  readonly result: CommandResult
  readonly stdout: string
  readonly stderr: string
  readonly exitCode: number
  readonly duration: number

  // Utilities
  stdoutLine(lineNumber: number): string
  stdoutMatching(pattern: RegExp): string | null

  // Lifecycle
  dispose(): Promise<void>
}
