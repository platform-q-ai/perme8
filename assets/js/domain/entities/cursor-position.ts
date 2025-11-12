/**
 * CursorPosition Entity
 *
 * Represents a user's cursor position in the document at a specific time.
 * Immutable entity that tracks where a user's cursor is and when it was there.
 *
 * This is a pure domain entity with no framework dependencies.
 * Cursor positions can become stale over time and should be checked for freshness.
 *
 * @example
 * ```typescript
 * // Create a new cursor position
 * const userId = new UserId('user-123')
 * const cursor = CursorPosition.create(userId, 42)
 *
 * // Check if cursor is stale (older than 5 seconds)
 * if (cursor.isStale(5000)) {
 *   console.log('Cursor is outdated')
 * }
 * ```
 *
 * @module domain/entities
 */

import { UserId } from '../value-objects/user-id'

export class CursorPosition {
  /**
   * User's unique identifier
   * @readonly
   */
  public readonly userId: UserId

  /**
   * Cursor position in the document (character offset)
   * @readonly
   */
  public readonly position: number

  /**
   * When the cursor position was recorded
   * @readonly
   */
  public readonly timestamp: Date

  /**
   * Creates a new CursorPosition entity
   *
   * Use the static factory method `CursorPosition.create()` for creating new cursor positions.
   * This constructor is primarily for reconstructing cursor positions from storage.
   *
   * @param userId - User's unique identifier
   * @param position - Cursor position in the document
   * @param timestamp - When the cursor position was recorded
   * @throws {Error} If position is negative
   *
   * @example
   * ```typescript
   * // Reconstruct from storage
   * const cursor = new CursorPosition(
   *   new UserId('user-123'),
   *   42,
   *   new Date('2025-11-12T10:00:00Z')
   * )
   * ```
   */
  constructor(userId: UserId, position: number, timestamp: Date) {
    if (position < 0) {
      throw new Error('Cursor position must be non-negative')
    }

    this.userId = userId
    this.position = position
    this.timestamp = timestamp
  }

  /**
   * Factory method to create a new cursor position
   *
   * Creates a new cursor position with the current timestamp.
   *
   * @param userId - User's unique identifier
   * @param position - Cursor position in the document
   * @returns A new CursorPosition entity with current timestamp
   * @throws {Error} If position is negative
   *
   * @example
   * ```typescript
   * const userId = new UserId('user-123')
   * const cursor = CursorPosition.create(userId, 42)
   *
   * console.log(cursor.position) // 42
   * console.log(cursor.timestamp) // Current time
   * ```
   */
  static create(userId: UserId, position: number): CursorPosition {
    return new CursorPosition(userId, position, new Date())
  }

  /**
   * Check if the cursor position is stale
   *
   * A cursor position is stale if it's older than the specified max age.
   * This is useful for hiding cursors that haven't been updated recently.
   *
   * @param maxAgeMs - Maximum age in milliseconds
   * @returns true if the cursor is older than maxAgeMs
   *
   * @example
   * ```typescript
   * const cursor = CursorPosition.create(userId, 42)
   *
   * // Check if cursor is older than 5 seconds
   * if (cursor.isStale(5000)) {
   *   console.log('Cursor is outdated - hide it')
   * } else {
   *   console.log('Cursor is fresh - show it')
   * }
   * ```
   */
  isStale(maxAgeMs: number): boolean {
    const age = Date.now() - this.timestamp.getTime()
    return age > maxAgeMs
  }
}
