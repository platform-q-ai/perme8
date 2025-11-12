/**
 * Participant Entity
 *
 * Represents a participant in a collaboration session.
 * Immutable entity that tracks user identity and participation status.
 *
 * This is a pure domain entity with no framework dependencies.
 * Participants are active when they join and can be deactivated when they leave.
 *
 * @example
 * ```typescript
 * // Create a new participant
 * const userId = new UserId('user-123')
 * const userName = new UserName('John Doe')
 * const userColor = new UserColor('#FF6B6B')
 * const participant = Participant.join(userId, userName, userColor)
 *
 * // Deactivate participant
 * const inactive = participant.deactivate()
 *
 * console.log(participant.isActive) // true
 * console.log(inactive.isActive) // false
 * ```
 *
 * @module domain/entities
 */

import { UserId } from '../value-objects/user-id'
import { UserName } from '../value-objects/user-name'
import { UserColor } from '../value-objects/user-color'

export class Participant {
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
   * When the participant joined the session
   * @readonly
   */
  public readonly joinedAt: Date

  /**
   * Whether the participant is currently active
   * @readonly
   */
  public readonly isActive: boolean

  /**
   * Creates a new Participant entity
   *
   * Use the static factory method `Participant.join()` for creating new participants.
   * This constructor is primarily for reconstructing participants from storage.
   *
   * @param userId - User's unique identifier
   * @param userName - User's display name
   * @param userColor - User's assigned color
   * @param joinedAt - When the participant joined
   * @param isActive - Whether the participant is active
   *
   * @example
   * ```typescript
   * // Reconstruct from storage
   * const participant = new Participant(
   *   new UserId('user-123'),
   *   new UserName('John Doe'),
   *   new UserColor('#FF6B6B'),
   *   new Date('2025-11-12T10:00:00Z'),
   *   true
   * )
   * ```
   */
  constructor(
    userId: UserId,
    userName: UserName,
    userColor: UserColor,
    joinedAt: Date,
    isActive: boolean
  ) {
    this.userId = userId
    this.userName = userName
    this.userColor = userColor
    this.joinedAt = joinedAt
    this.isActive = isActive
  }

  /**
   * Factory method to create a new active participant
   *
   * Creates a new participant who has just joined the session.
   * The participant is marked as active and joinedAt is set to current time.
   *
   * @param userId - User's unique identifier
   * @param userName - User's display name
   * @param userColor - User's assigned color
   * @returns A new active Participant entity
   *
   * @example
   * ```typescript
   * const userId = new UserId('user-123')
   * const userName = new UserName('John Doe')
   * const userColor = new UserColor('#FF6B6B')
   * const participant = Participant.join(userId, userName, userColor)
   *
   * console.log(participant.isActive) // true
   * console.log(participant.joinedAt) // Current timestamp
   * ```
   */
  static join(userId: UserId, userName: UserName, userColor: UserColor): Participant {
    return new Participant(userId, userName, userColor, new Date(), true)
  }

  /**
   * Deactivate this participant
   *
   * Returns a new Participant instance with isActive set to false.
   * All other properties remain unchanged.
   * The original participant is unchanged (immutability).
   *
   * @returns A new Participant instance marked as inactive
   *
   * @example
   * ```typescript
   * const active = Participant.join(
   *   new UserId('user-123'),
   *   new UserName('John Doe'),
   *   new UserColor('#FF6B6B')
   * )
   *
   * const inactive = active.deactivate()
   *
   * console.log(active.isActive) // true (unchanged)
   * console.log(inactive.isActive) // false
   * ```
   */
  deactivate(): Participant {
    return new Participant(
      this.userId,
      this.userName,
      this.userColor,
      this.joinedAt,
      false
    )
  }
}
