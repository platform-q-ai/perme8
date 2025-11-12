/**
 * CollaborationSession Entity
 *
 * Represents a collaborative editing session with multiple participants.
 * Immutable entity that manages participants and enforces collaboration rules.
 *
 * This is a pure domain entity with no framework dependencies.
 * Sessions track participants (active or inactive) and provide query methods.
 *
 * @example
 * ```typescript
 * // Create a new session
 * const sessionId = 'session-123'
 * const documentId = new DocumentId('doc-456')
 * const session = CollaborationSession.create(sessionId, documentId)
 *
 * // Add participants
 * const participant = Participant.join(userId, userName, userColor)
 * const withParticipant = session.addParticipant(participant)
 *
 * // Check session state
 * console.log(withParticipant.getParticipantCount()) // 1
 * console.log(withParticipant.getActiveParticipants()) // [participant]
 *
 * // Deactivate participant
 * const updated = withParticipant.deactivateParticipant(userId)
 * console.log(updated.getActiveParticipants()) // []
 * ```
 *
 * @module domain/entities
 */

import { DocumentId } from '../value-objects/document-id'
import { UserId } from '../value-objects/user-id'
import { Participant } from './participant'

export class CollaborationSession {
  /**
   * Unique identifier for the session
   * @readonly
   */
  public readonly sessionId: string

  /**
   * Document being collaborated on
   * @readonly
   */
  public readonly documentId: DocumentId

  /**
   * When the session was created
   * @readonly
   */
  public readonly createdAt: Date

  /**
   * Map of participants (userId -> Participant)
   * @private
   */
  private readonly participants: Map<string, Participant>

  /**
   * Creates a new CollaborationSession entity
   *
   * Use the static factory method `CollaborationSession.create()` for creating new sessions.
   * This constructor is primarily for reconstructing sessions from storage.
   *
   * @param sessionId - Unique identifier for the session
   * @param documentId - Document being collaborated on
   * @param createdAt - When the session was created
   * @param participants - Map of participants
   *
   * @example
   * ```typescript
   * // Reconstruct from storage
   * const session = new CollaborationSession(
   *   'session-123',
   *   new DocumentId('doc-456'),
   *   new Date('2025-11-12T10:00:00Z'),
   *   new Map([['user-1', participant1]])
   * )
   * ```
   */
  constructor(
    sessionId: string,
    documentId: DocumentId,
    createdAt: Date,
    participants: Map<string, Participant>
  ) {
    if (!sessionId || sessionId.trim() === '') {
      throw new Error('Session ID cannot be empty')
    }

    this.sessionId = sessionId
    this.documentId = documentId
    this.createdAt = createdAt
    this.participants = participants
  }

  /**
   * Factory method to create a new collaboration session
   *
   * Creates a new session with no participants and current timestamp.
   *
   * @param sessionId - Unique identifier for the session
   * @param documentId - Document being collaborated on
   * @returns A new CollaborationSession entity
   *
   * @example
   * ```typescript
   * const sessionId = 'session-123'
   * const documentId = new DocumentId('doc-456')
   * const session = CollaborationSession.create(sessionId, documentId)
   *
   * console.log(session.getParticipantCount()) // 0
   * ```
   */
  static create(sessionId: string, documentId: DocumentId): CollaborationSession {
    return new CollaborationSession(
      sessionId,
      documentId,
      new Date(),
      new Map()
    )
  }

  /**
   * Add or update a participant in the session
   *
   * Returns a new CollaborationSession instance with the participant added.
   * If a participant with the same user ID already exists, they are replaced.
   * The original session is unchanged (immutability).
   *
   * @param participant - The participant to add
   * @returns A new CollaborationSession instance with the participant
   *
   * @example
   * ```typescript
   * const session = CollaborationSession.create('session-1', docId)
   * const participant = Participant.join(userId, userName, userColor)
   *
   * const updated = session.addParticipant(participant)
   *
   * console.log(updated.hasParticipant(userId)) // true
   * console.log(session.hasParticipant(userId)) // false (unchanged)
   * ```
   */
  addParticipant(participant: Participant): CollaborationSession {
    const newParticipants = new Map(this.participants)
    newParticipants.set(participant.userId.value, participant)

    return new CollaborationSession(
      this.sessionId,
      this.documentId,
      this.createdAt,
      newParticipants
    )
  }

  /**
   * Remove a participant from the session
   *
   * Returns a new CollaborationSession instance with the participant removed.
   * If the participant doesn't exist, returns a new instance with no changes.
   * The original session is unchanged (immutability).
   *
   * @param userId - User ID of the participant to remove
   * @returns A new CollaborationSession instance without the participant
   *
   * @example
   * ```typescript
   * const session = CollaborationSession.create('session-1', docId)
   *   .addParticipant(participant)
   *
   * const updated = session.removeParticipant(userId)
   *
   * console.log(updated.hasParticipant(userId)) // false
   * console.log(session.hasParticipant(userId)) // true (unchanged)
   * ```
   */
  removeParticipant(userId: UserId): CollaborationSession {
    const newParticipants = new Map(this.participants)
    newParticipants.delete(userId.value)

    return new CollaborationSession(
      this.sessionId,
      this.documentId,
      this.createdAt,
      newParticipants
    )
  }

  /**
   * Deactivate a participant in the session
   *
   * Returns a new CollaborationSession instance with the participant marked as inactive.
   * The participant remains in the session but with isActive set to false.
   * If the participant doesn't exist, returns a new instance with no changes.
   * The original session is unchanged (immutability).
   *
   * @param userId - User ID of the participant to deactivate
   * @returns A new CollaborationSession instance with participant deactivated
   *
   * @example
   * ```typescript
   * const session = CollaborationSession.create('session-1', docId)
   *   .addParticipant(participant)
   *
   * const updated = session.deactivateParticipant(userId)
   *
   * console.log(updated.getParticipant(userId)?.isActive) // false
   * console.log(updated.hasParticipant(userId)) // true (still in session)
   * console.log(session.getParticipant(userId)?.isActive) // true (unchanged)
   * ```
   */
  deactivateParticipant(userId: UserId): CollaborationSession {
    const participant = this.participants.get(userId.value)
    if (!participant) {
      return new CollaborationSession(
        this.sessionId,
        this.documentId,
        this.createdAt,
        new Map(this.participants)
      )
    }

    const deactivated = participant.deactivate()
    const newParticipants = new Map(this.participants)
    newParticipants.set(userId.value, deactivated)

    return new CollaborationSession(
      this.sessionId,
      this.documentId,
      this.createdAt,
      newParticipants
    )
  }

  /**
   * Get a participant by user ID
   *
   * @param userId - User ID of the participant to retrieve
   * @returns The participant if found, null otherwise
   *
   * @example
   * ```typescript
   * const session = CollaborationSession.create('session-1', docId)
   *   .addParticipant(participant)
   *
   * const retrieved = session.getParticipant(userId)
   * console.log(retrieved?.userName.value) // 'John Doe'
   *
   * const notFound = session.getParticipant(new UserId('unknown'))
   * console.log(notFound) // null
   * ```
   */
  getParticipant(userId: UserId): Participant | null {
    return this.participants.get(userId.value) ?? null
  }

  /**
   * Get all active participants
   *
   * Returns an array of participants where isActive is true.
   * Inactive participants are excluded from the result.
   *
   * @returns Array of active participants
   *
   * @example
   * ```typescript
   * const session = CollaborationSession.create('session-1', docId)
   *   .addParticipant(participant1)
   *   .addParticipant(participant2)
   *   .deactivateParticipant(participant2.userId)
   *
   * const active = session.getActiveParticipants()
   * console.log(active.length) // 1
   * console.log(active[0].userId) // participant1.userId
   * ```
   */
  getActiveParticipants(): Participant[] {
    return Array.from(this.participants.values()).filter(p => p.isActive)
  }

  /**
   * Check if a participant exists in the session
   *
   * Returns true if the participant exists (active or inactive).
   *
   * @param userId - User ID to check
   * @returns true if the participant is in the session
   *
   * @example
   * ```typescript
   * const session = CollaborationSession.create('session-1', docId)
   *   .addParticipant(participant)
   *
   * console.log(session.hasParticipant(participant.userId)) // true
   * console.log(session.hasParticipant(new UserId('unknown'))) // false
   *
   * // Still returns true for inactive participants
   * const updated = session.deactivateParticipant(participant.userId)
   * console.log(updated.hasParticipant(participant.userId)) // true
   * ```
   */
  hasParticipant(userId: UserId): boolean {
    return this.participants.has(userId.value)
  }

  /**
   * Get the total number of participants
   *
   * Returns the count of all participants (active and inactive).
   *
   * @returns Number of participants in the session
   *
   * @example
   * ```typescript
   * const session = CollaborationSession.create('session-1', docId)
   *   .addParticipant(participant1)
   *   .addParticipant(participant2)
   *
   * console.log(session.getParticipantCount()) // 2
   *
   * // Inactive participants are still counted
   * const updated = session.deactivateParticipant(participant1.userId)
   * console.log(updated.getParticipantCount()) // 2
   * ```
   */
  getParticipantCount(): number {
    return this.participants.size
  }
}
