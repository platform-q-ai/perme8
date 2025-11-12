/**
 * UserName Value Object
 *
 * Represents a user's display name in the domain.
 * Immutable value object that encapsulates name validation and normalization.
 *
 * This is a pure domain value object with no framework dependencies.
 * It ensures that user names are always valid, non-empty, and within length constraints.
 *
 * @example
 * ```typescript
 * const userName = new UserName('John Doe')
 * const sameName = new UserName('  John Doe  ') // Trimmed automatically
 * console.log(userName.equals(sameName)) // true
 * ```
 *
 * @module domain/value-objects
 */

export class UserName {
  /**
   * The immutable user name value (always trimmed)
   * @readonly
   */
  public readonly value: string

  /**
   * Maximum allowed length for a user name
   */
  private static readonly MAX_LENGTH = 100

  /**
   * Creates a new UserName value object
   *
   * @param value - The user name string
   * @throws {Error} If the value is empty, null, undefined, whitespace-only, or exceeds max length
   *
   * @example
   * ```typescript
   * const userName = new UserName('John Doe') // Valid
   * const trimmed = new UserName('  Jane  ') // Valid, trimmed to 'Jane'
   * const invalid = new UserName('') // Throws Error
   * ```
   */
  constructor(value: string) {
    if (!value || value.trim() === '') {
      throw new Error('User name cannot be empty')
    }

    const trimmed = value.trim()

    if (trimmed.length > UserName.MAX_LENGTH) {
      throw new Error('User name cannot exceed 100 characters')
    }

    this.value = trimmed
  }

  /**
   * Check value equality with another UserName
   *
   * Two UserNames are equal if they have the same trimmed value.
   * This implements value equality semantics (not reference equality).
   *
   * @param other - The UserName to compare with
   * @returns true if both UserNames have the same value
   *
   * @example
   * ```typescript
   * const name1 = new UserName('John Doe')
   * const name2 = new UserName('  John Doe  ')
   * const name3 = new UserName('Jane Smith')
   * console.log(name1.equals(name2)) // true (both trimmed to 'John Doe')
   * console.log(name1.equals(name3)) // false
   * ```
   */
  equals(other: UserName): boolean {
    return this.value === other.value
  }

  /**
   * Get string representation of the UserName
   *
   * @returns The user name string value (trimmed)
   *
   * @example
   * ```typescript
   * const userName = new UserName('  John Doe  ')
   * console.log(userName.toString()) // 'John Doe'
   * ```
   */
  toString(): string {
    return this.value
  }
}
