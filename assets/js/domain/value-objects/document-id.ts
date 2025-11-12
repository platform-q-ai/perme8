/**
 * DocumentId Value Object
 *
 * Represents a unique document identifier in the domain.
 * Immutable value object that encapsulates document ID validation.
 *
 * This is a pure domain value object with no framework dependencies.
 * It ensures that document IDs are always valid and provides value equality semantics.
 *
 * @example
 * ```typescript
 * const docId = new DocumentId('doc-123')
 * const sameDoc = new DocumentId('doc-123')
 * console.log(docId.equals(sameDoc)) // true
 *
 * // Also supports UUID format
 * const uuidDoc = new DocumentId('550e8400-e29b-41d4-a716-446655440000')
 * ```
 *
 * @module domain/value-objects
 */

export class DocumentId {
  /**
   * The immutable document ID value
   * @readonly
   */
  public readonly value: string

  /**
   * Creates a new DocumentId value object
   *
   * @param value - The document ID string (can be any non-empty string or UUID)
   * @throws {Error} If the value is empty, null, undefined, or whitespace-only
   *
   * @example
   * ```typescript
   * const docId = new DocumentId('doc-123') // Valid
   * const uuidId = new DocumentId('550e8400-e29b-41d4-a716-446655440000') // Valid
   * const invalid = new DocumentId('') // Throws Error
   * ```
   */
  constructor(value: string) {
    if (!value || value.trim() === '') {
      throw new Error('Document ID cannot be empty')
    }

    this.value = value
  }

  /**
   * Check value equality with another DocumentId
   *
   * Two DocumentIds are equal if they have the same value string.
   * This implements value equality semantics (not reference equality).
   *
   * @param other - The DocumentId to compare with
   * @returns true if both DocumentIds have the same value
   *
   * @example
   * ```typescript
   * const id1 = new DocumentId('doc-123')
   * const id2 = new DocumentId('doc-123')
   * const id3 = new DocumentId('doc-456')
   * console.log(id1.equals(id2)) // true
   * console.log(id1.equals(id3)) // false
   * ```
   */
  equals(other: DocumentId): boolean {
    return this.value === other.value
  }

  /**
   * Get string representation of the DocumentId
   *
   * @returns The document ID string value
   *
   * @example
   * ```typescript
   * const docId = new DocumentId('doc-123')
   * console.log(docId.toString()) // 'doc-123'
   * ```
   */
  toString(): string {
    return this.value
  }
}
