/**
 * Edit Permissions Policy
 *
 * Pure policy functions for determining edit permissions in collaboration sessions.
 * These are stateless business rules that can be composed.
 *
 * This is pure domain logic with no framework dependencies.
 * All functions are pure - they don't modify inputs and return the same output
 * for the same inputs.
 *
 * @example
 * ```typescript
 * // Check if user can edit
 * const participant = Participant.join(userId, userName, userColor)
 * const canEdit = canUserEdit(participant) // true
 *
 * // Check if session is full
 * const participants = new Map([['user-1', participant]])
 * const full = isSessionFull(participants, 5) // false
 *
 * // Check if participant can join
 * const newParticipant = Participant.join(userId2, userName2, userColor2)
 * const canJoin = canParticipantJoin(participants, newParticipant, 5) // true
 * ```
 *
 * @module domain/policies
 */

import { Participant } from '../entities/participant'

/**
 * Check if a participant can edit the document
 *
 * A participant can edit if they are currently active.
 * Inactive participants (who have left) cannot edit.
 *
 * @param participant - The participant to check
 * @returns true if the participant can edit
 *
 * @example
 * ```typescript
 * const active = Participant.join(userId, userName, userColor)
 * console.log(canUserEdit(active)) // true
 *
 * const inactive = active.deactivate()
 * console.log(canUserEdit(inactive)) // false
 * ```
 */
export function canUserEdit(participant: Participant): boolean {
  return participant.isActive
}

/**
 * Check if a participant can join the session
 *
 * A participant can join if:
 * - They are already in the session (rejoining), OR
 * - The session is not full (has capacity)
 *
 * @param participants - Current session participants
 * @param participant - The participant trying to join
 * @param maxParticipants - Maximum allowed participants
 * @returns true if the participant can join
 *
 * @example
 * ```typescript
 * const participants = new Map([
 *   ['user-1', participant1],
 *   ['user-2', participant2]
 * ])
 *
 * // New participant when session has space
 * const canJoin = canParticipantJoin(participants, newParticipant, 5) // true
 *
 * // New participant when session is full
 * const canJoin = canParticipantJoin(participants, newParticipant, 2) // false
 *
 * // Existing participant can always rejoin
 * const canJoin = canParticipantJoin(participants, participant1, 2) // true
 * ```
 */
export function canParticipantJoin(
  participants: Map<string, Participant>,
  participant: Participant,
  maxParticipants: number
): boolean {
  // Check if participant already exists (rejoining)
  const participantId = participant.userId.value
  if (participants.has(participantId)) {
    return true
  }

  // Check if session has capacity
  return !isSessionFull(participants, maxParticipants)
}

/**
 * Check if a session is at maximum capacity
 *
 * A session is full when the number of participants (active or inactive)
 * equals or exceeds the maximum allowed.
 *
 * @param participants - Current session participants
 * @param maxParticipants - Maximum allowed participants
 * @returns true if the session is at or over capacity
 *
 * @example
 * ```typescript
 * const participants = new Map([
 *   ['user-1', participant1],
 *   ['user-2', participant2]
 * ])
 *
 * console.log(isSessionFull(participants, 5)) // false
 * console.log(isSessionFull(participants, 2)) // true
 * console.log(isSessionFull(participants, 1)) // true (over capacity)
 * ```
 */
export function isSessionFull(
  participants: Map<string, Participant>,
  maxParticipants: number
): boolean {
  return participants.size >= maxParticipants
}
