import { VariableNotFoundError } from '../../domain/errors/index.ts'

export class VariableService {
  // Shared store persists across scenarios within a test run.
  // This allows setup scenarios to store IDs that subsequent scenarios can reference.
  private static shared = new Map<string, unknown>()

  // Per-scenario store is cleared on each reset.
  private local = new Map<string, unknown>()

  set(name: string, value: unknown): void {
    this.local.set(name, value)
    VariableService.shared.set(name, value)
  }

  get<T>(name: string): T {
    // Check local (current scenario) first, then shared (cross-scenario)
    if (this.local.has(name)) {
      return this.local.get(name) as T
    }
    if (VariableService.shared.has(name)) {
      return VariableService.shared.get(name) as T
    }
    throw new VariableNotFoundError(name)
  }

  has(name: string): boolean {
    return this.local.has(name) || VariableService.shared.has(name)
  }

  /** Clears per-scenario variables only. Shared variables persist. */
  clear(): void {
    this.local.clear()
  }

  /** Clears all variables including shared state. Called between features or at end of run. */
  static clearAll(): void {
    VariableService.shared.clear()
  }
}
