import { Given } from '@cucumber/cucumber'
import { TestWorld } from '../../world/index.ts'

export interface EnvironmentContext {
  cli: { setEnv(name: string, value: string): void; clearEnv(name: string): void; setWorkingDir(dir: string): void }
  interpolate(value: string): string
}

export function setEnvVar(context: EnvironmentContext, name: string, value: string): void {
  context.cli.setEnv(name, context.interpolate(value))
}

export function clearEnvVar(context: EnvironmentContext, name: string): void {
  context.cli.clearEnv(name)
}

export function setEnvVarsFromTable(context: EnvironmentContext, dataTable: { rowsHash(): Record<string, string> }): void {
  const env = dataTable.rowsHash() as Record<string, string>
  for (const [name, value] of Object.entries(env)) {
    context.cli.setEnv(name, context.interpolate(value))
  }
}

export function setWorkingDir(context: EnvironmentContext, dir: string): void {
  context.cli.setWorkingDir(context.interpolate(dir))
}

Given<TestWorld>(
  'I set environment variable {string} to {string}',
  function (name: string, value: string) {
    setEnvVar(this, name, value)
  },
)

Given<TestWorld>(
  'I clear environment variable {string}',
  function (name: string) {
    clearEnvVar(this, name)
  },
)

Given<TestWorld>(
  'I set the following environment variables:',
  function (dataTable) {
    setEnvVarsFromTable(this, dataTable)
  },
)

Given<TestWorld>(
  'I set working directory to {string}',
  function (dir: string) {
    setWorkingDir(this, dir)
  },
)
