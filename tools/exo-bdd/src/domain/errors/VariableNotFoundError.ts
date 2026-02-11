import { DomainError } from './DomainError.ts'

export class VariableNotFoundError extends DomainError {
  readonly code = 'VARIABLE_NOT_FOUND'
  constructor(name: string) {
    super(`Variable "${name}" is not defined`)
  }
}
