/**
 * UserId Value Object
 *
 * Represents a unique user identifier in the domain.
 * Immutable value object that encapsulates user ID validation.
 *
 * This is a pure domain value object with no framework dependencies.
 * It ensures that user IDs are always valid and provides value equality semantics.
 *
 * @example
 * ```typescript
 * const userId = new UserId('user-123')
 * const sameUser = new UserId('user-123')
 * console.log(userId.equals(sameUser)) // true
 * ```
 *
 * @module domain/value-objects
 */

export class UserId {
  /**
   * The immutable user ID value
   * @readonly
   */
  public readonly value: string

  /**
   * Creates a new UserId value object
   *
   * @param value - The user ID string
   * @throws {Error} If the value is empty, null, undefined, or whitespace-only
   *
   * @example
   * ```typescript
   * const userId = new UserId('user-123') // Valid
   * const invalid = new UserId('') // Throws Error
   * ```
   */
  constructor(value: string) {
    if (!value || value.trim() === '') {
      throw new Error('User ID cannot be empty')
    }

    this.value = value
  }

  /**
   * Check value equality with another UserId
   *
   * Two UserIds are equal if they have the same value string.
   * This implements value equality semantics (not reference equality).
   *
   * @param other - The UserId to compare with
   * @returns true if both UserIds have the same value
   *
   * @example
   * ```typescript
   * const id1 = new UserId('user-123')
   * const id2 = new UserId('user-123')
   * const id3 = new UserId('user-456')
   * console.log(id1.equals(id2)) // true
   * console.log(id1.equals(id3)) // false
   * ```
   */
  equals(other: UserId): boolean {
    return this.value === other.value
  }

  /**
   * Get string representation of the UserId
   *
   * @returns The user ID string value
   *
   * @example
   * ```typescript
   * const userId = new UserId('user-123')
   * console.log(userId.toString()) // 'user-123'
   * ```
   */
  toString(): string {
    return this.value
  }
}
