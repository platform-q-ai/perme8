import { VariableNotFoundError } from '../../domain/errors/index.ts'

export class VariableService {
  private variables = new Map<string, unknown>()

  set(name: string, value: unknown): void {
    this.variables.set(name, value)
  }

  get<T>(name: string): T {
    if (!this.variables.has(name)) {
      throw new VariableNotFoundError(name)
    }
    return this.variables.get(name) as T
  }

  has(name: string): boolean {
    return this.variables.has(name)
  }

  clear(): void {
    this.variables.clear()
  }
}
