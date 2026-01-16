/**
 * QueryId Value Object
 *
 * Represents a unique identifier for an agent query.
 * This is a value object in the domain layer - pure business logic with no dependencies.
 *
 * Responsibilities:
 * - Validate query ID format
 * - Generate unique query IDs
 * - Provide equality comparison
 */
export class QueryId {
  private readonly _value: string

  constructor(value: string) {
    if (!value || value.trim().length === 0) {
      throw new Error('Query ID cannot be empty')
    }

    this._value = value
  }

  get value(): string {
    return this._value
  }

  /**
   * Generate a unique query ID
   *
   * Format: query_{timestamp}_{random}
   * Example: query_1234567890_abc123def
   */
  static generate(): QueryId {
    const timestamp = Date.now()
    const random = Math.random().toString(36).substring(2, 11)
    return new QueryId(`query_${timestamp}_${random}`)
  }

  /**
   * Check equality with another QueryId
   */
  equals(other: QueryId): boolean {
    return this._value === other._value
  }

  /**
   * String representation
   */
  toString(): string {
    return this._value
  }
}
