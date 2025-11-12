/**
 * UserAwareness Entity
 *
 * Represents a user's awareness state in a collaborative session.
 * Tracks user identity, selection, cursor position, and activity status.
 *
 * This is a pure domain entity with no framework dependencies.
 * UserAwareness is immutable - all operations return new instances.
 *
 * @example
 * ```typescript
 * // Create awareness for a user
 * const userId = new UserId('user-123')
 * const userName = new UserName('John Doe')
 * const userColor = new UserColor('#FF6B6B')
 * const awareness = UserAwareness.create(userId, userName, userColor)
 *
 * // Update their selection
 * const withSelection = awareness.updateSelection(new Selection(5, 10))
 *
 * // Update their cursor position
 * const withCursor = withSelection.updateCursor(10)
 *
 * // Check if user is active
 * if (withCursor.isActive(5000)) {
 *   console.log('User is active')
 * }
 * ```
 *
 * @module domain/entities
 */

import { UserId } from '../value-objects/user-id'
import { UserName } from '../value-objects/user-name'
import { UserColor } from '../value-objects/user-color'
import { Selection } from '../value-objects/selection'
import { CursorPosition } from './cursor-position'

export class UserAwareness {
  /**
   * User's unique identifier
   * @readonly
   */
  public readonly userId: UserId

  /**
   * User's display name
   * @readonly
   */
  public readonly userName: UserName

  /**
   * User's assigned color
   * @readonly
   */
  public readonly userColor: UserColor

  /**
   * User's current selection (null if no selection)
   * @readonly
   */
  public readonly selection: Selection | null

  /**
   * User's current cursor position (null if no cursor)
   * @readonly
   */
  public readonly cursorPosition: CursorPosition | null

  /**
   * When the user last performed any activity
   * @readonly
   */
  public readonly lastActivity: Date

  /**
   * Creates a new UserAwareness entity
   *
   * Use the static factory method `UserAwareness.create()` for creating new awareness.
   * This constructor is primarily for reconstructing awareness from storage or
   * for creating updated instances.
   *
   * @param userId - User's unique identifier
   * @param userName - User's display name
   * @param userColor - User's assigned color
   * @param selection - User's current selection (null if none)
   * @param cursorPosition - User's current cursor position (null if none)
   * @param lastActivity - When the user last performed any activity
   *
   * @example
   * ```typescript
   * // Reconstruct from storage
   * const awareness = new UserAwareness(
   *   new UserId('user-123'),
   *   new UserName('John Doe'),
   *   new UserColor('#FF6B6B'),
   *   new Selection(5, 10),
   *   CursorPosition.create(userId, 10),
   *   new Date('2025-11-12T10:00:00Z')
   * )
   * ```
   */
  constructor(
    userId: UserId,
    userName: UserName,
    userColor: UserColor,
    selection: Selection | null,
    cursorPosition: CursorPosition | null,
    lastActivity: Date
  ) {
    this.userId = userId
    this.userName = userName
    this.userColor = userColor
    this.selection = selection
    this.cursorPosition = cursorPosition
    this.lastActivity = lastActivity
  }

  /**
   * Factory method to create a new user awareness
   *
   * Creates a new awareness state for a user with no selection or cursor.
   * The lastActivity is set to current time.
   *
   * @param userId - User's unique identifier
   * @param userName - User's display name
   * @param userColor - User's assigned color
   * @returns A new UserAwareness entity
   *
   * @example
   * ```typescript
   * const userId = new UserId('user-123')
   * const userName = new UserName('John Doe')
   * const userColor = new UserColor('#FF6B6B')
   * const awareness = UserAwareness.create(userId, userName, userColor)
   *
   * console.log(awareness.hasSelection()) // false
   * console.log(awareness.hasCursor()) // false
   * console.log(awareness.isActive(5000)) // true (just created)
   * ```
   */
  static create(userId: UserId, userName: UserName, userColor: UserColor): UserAwareness {
    return new UserAwareness(userId, userName, userColor, null, null, new Date())
  }

  /**
   * Update the user's selection
   *
   * Returns a new UserAwareness instance with the updated selection.
   * The lastActivity timestamp is updated to current time.
   * All other properties remain unchanged.
   *
   * @param selection - The new selection
   * @returns A new UserAwareness instance with updated selection
   *
   * @example
   * ```typescript
   * const awareness = UserAwareness.create(userId, userName, userColor)
   * const selection = new Selection(5, 10)
   *
   * const updated = awareness.updateSelection(selection)
   *
   * console.log(awareness.selection) // null (unchanged)
   * console.log(updated.selection) // Selection { anchor: 5, head: 10 }
   * ```
   */
  updateSelection(selection: Selection): UserAwareness {
    return new UserAwareness(
      this.userId,
      this.userName,
      this.userColor,
      selection,
      this.cursorPosition,
      new Date()
    )
  }

  /**
   * Update the user's cursor position
   *
   * Returns a new UserAwareness instance with a new cursor position.
   * Creates a new CursorPosition entity with current timestamp.
   * The lastActivity timestamp is updated to current time.
   * All other properties remain unchanged.
   *
   * @param position - The new cursor position
   * @returns A new UserAwareness instance with updated cursor
   *
   * @example
   * ```typescript
   * const awareness = UserAwareness.create(userId, userName, userColor)
   *
   * const updated = awareness.updateCursor(42)
   *
   * console.log(awareness.cursorPosition) // null (unchanged)
   * console.log(updated.cursorPosition?.position) // 42
   * ```
   */
  updateCursor(position: number): UserAwareness {
    const cursorPosition = CursorPosition.create(this.userId, position)
    return new UserAwareness(
      this.userId,
      this.userName,
      this.userColor,
      this.selection,
      cursorPosition,
      new Date()
    )
  }

  /**
   * Clear the user's selection
   *
   * Returns a new UserAwareness instance with selection set to null.
   * The lastActivity timestamp is updated to current time.
   * All other properties remain unchanged.
   *
   * @returns A new UserAwareness instance with null selection
   *
   * @example
   * ```typescript
   * const awareness = UserAwareness.create(userId, userName, userColor)
   * const withSelection = awareness.updateSelection(new Selection(5, 10))
   *
   * const cleared = withSelection.clearSelection()
   *
   * console.log(withSelection.selection) // Selection { anchor: 5, head: 10 } (unchanged)
   * console.log(cleared.selection) // null
   * ```
   */
  clearSelection(): UserAwareness {
    return new UserAwareness(
      this.userId,
      this.userName,
      this.userColor,
      null,
      this.cursorPosition,
      new Date()
    )
  }

  /**
   * Check if the user is active
   *
   * A user is active if their lastActivity is within the max inactive time.
   * This is useful for hiding inactive users from the collaboration UI.
   *
   * @param maxInactiveMs - Maximum inactive time in milliseconds
   * @returns true if the user is active (recent activity)
   *
   * @example
   * ```typescript
   * const awareness = UserAwareness.create(userId, userName, userColor)
   *
   * // Check if user has activity in the last 30 seconds
   * if (awareness.isActive(30000)) {
   *   console.log('User is active - show their cursor')
   * } else {
   *   console.log('User is inactive - hide their cursor')
   * }
   * ```
   */
  isActive(maxInactiveMs: number): boolean {
    const inactiveTime = Date.now() - this.lastActivity.getTime()
    return inactiveTime <= maxInactiveMs
  }

  /**
   * Check if the user has a selection
   *
   * Returns true if the user has a non-null selection.
   *
   * @returns true if selection exists
   *
   * @example
   * ```typescript
   * const awareness = UserAwareness.create(userId, userName, userColor)
   * console.log(awareness.hasSelection()) // false
   *
   * const withSelection = awareness.updateSelection(new Selection(5, 10))
   * console.log(withSelection.hasSelection()) // true
   * ```
   */
  hasSelection(): boolean {
    return this.selection !== null
  }

  /**
   * Check if the user has a cursor position
   *
   * Returns true if the user has a non-null cursor position.
   *
   * @returns true if cursor position exists
   *
   * @example
   * ```typescript
   * const awareness = UserAwareness.create(userId, userName, userColor)
   * console.log(awareness.hasCursor()) // false
   *
   * const withCursor = awareness.updateCursor(42)
   * console.log(withCursor.hasCursor()) // true
   * ```
   */
  hasCursor(): boolean {
    return this.cursorPosition !== null
  }
}
