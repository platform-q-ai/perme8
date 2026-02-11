import { DomainError } from './DomainError.ts'

export class AdapterNotConfiguredError extends DomainError {
  readonly code = 'ADAPTER_NOT_CONFIGURED'
  constructor(adapter: string) {
    super(`Adapter "${adapter}" is not configured`)
  }
}
