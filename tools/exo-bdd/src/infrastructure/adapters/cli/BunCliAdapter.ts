import { spawn } from 'node:child_process'
import type { CliPort } from '../../../application/ports/index.ts'
import type { CliAdapterConfig } from '../../../application/config/index.ts'
import type { CommandResult } from '../../../domain/entities/index.ts'

/**
 * Executes a shell command via Node's child_process.spawn and collects output.
 * Works under both Bun and Node runtimes.
 */
function execShell(
  command: string,
  options: { cwd: string; env: Record<string, string>; stdin?: string; timeout?: number },
): Promise<CommandResult> {
  return new Promise((resolve) => {
    const startTime = Date.now()
    const proc = spawn('sh', ['-c', command], {
      cwd: options.cwd,
      env: { ...process.env, ...options.env },
      stdio: ['pipe', 'pipe', 'pipe'],
      timeout: options.timeout,
    })

    const stdoutChunks: Buffer[] = []
    const stderrChunks: Buffer[] = []

    proc.stdout.on('data', (chunk: Buffer) => stdoutChunks.push(chunk))
    proc.stderr.on('data', (chunk: Buffer) => stderrChunks.push(chunk))

    if (options.stdin != null) {
      proc.stdin.write(options.stdin)
      proc.stdin.end()
    } else {
      proc.stdin.end()
    }

    proc.on('close', (code, signal) => {
      const exitCode = signal === 'SIGTERM' ? 124 : (code ?? 1)
      resolve({
        stdout: Buffer.concat(stdoutChunks).toString(),
        stderr: Buffer.concat(stderrChunks).toString(),
        exitCode,
        duration: Date.now() - startTime,
      })
    })

    proc.on('error', (err) => {
      resolve({
        stdout: Buffer.concat(stdoutChunks).toString(),
        stderr: err.message,
        exitCode: 1,
        duration: Date.now() - startTime,
      })
    })
  })
}

export class BunCliAdapter implements CliPort {
  private env: Record<string, string> = {}
  private workingDir: string
  private _result?: CommandResult
  private _lastCommand?: string

  constructor(readonly config: CliAdapterConfig) {
    this.workingDir = config.workingDir ?? process.cwd()
    if (config.env) {
      Object.assign(this.env, config.env)
    }
  }

  private guardResult(): CommandResult {
    if (!this._result) {
      throw new Error('No command has been run yet. Call run() before accessing results.')
    }
    return this._result
  }

  setEnv(name: string, value: string): this {
    this.env[name] = value
    return this
  }

  setEnvs(env: Record<string, string>): this {
    Object.assign(this.env, env)
    return this
  }

  clearEnv(name: string): this {
    delete this.env[name]
    return this
  }

  setWorkingDir(dir: string): this {
    this.workingDir = dir
    return this
  }

  async run(command: string): Promise<CommandResult> {
    this._lastCommand = command
    const timeoutMs = this.config.timeout
    if (timeoutMs != null) {
      return this.runWithTimeout(command, timeoutMs)
    }

    this._result = await execShell(command, {
      cwd: this.workingDir,
      env: this.env,
    })

    return this._result
  }

  async runWithStdin(command: string, stdin: string): Promise<CommandResult> {
    this._lastCommand = command
    this._result = await execShell(command, {
      cwd: this.workingDir,
      env: this.env,
      stdin,
    })

    return this._result
  }

  async runWithTimeout(command: string, timeoutMs: number): Promise<CommandResult> {
    this._lastCommand = command
    const result = await execShell(command, {
      cwd: this.workingDir,
      env: this.env,
      timeout: timeoutMs,
    })

    // If the process was killed by timeout, normalize the result
    if (result.exitCode === 124) {
      result.stderr = result.stderr || `Command timed out after ${timeoutMs}ms`
    }

    this._result = result
    return this._result
  }

  get lastCommand(): string | undefined {
    return this._lastCommand
  }

  get result(): CommandResult {
    return this.guardResult()
  }

  get stdout(): string {
    return this.guardResult().stdout
  }

  get stderr(): string {
    return this.guardResult().stderr
  }

  get exitCode(): number {
    return this.guardResult().exitCode
  }

  get duration(): number {
    return this.guardResult().duration
  }

  stdoutLine(lineNumber: number): string {
    const r = this.guardResult()
    const lines = r.stdout.split('\n')
    if (lineNumber < 1 || lineNumber > lines.length) {
      throw new Error(`Line ${lineNumber} does not exist (stdout has ${lines.length} lines)`)
    }
    return lines[lineNumber - 1]!
  }

  stdoutMatching(pattern: RegExp): string | null {
    const match = this.guardResult().stdout.match(pattern)
    return match ? (match[1] ?? match[0]) : null
  }

  async dispose(): Promise<void> {
    // No cleanup needed for CLI adapter
  }
}
