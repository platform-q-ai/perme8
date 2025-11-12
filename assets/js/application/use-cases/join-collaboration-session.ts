/**
 * JoinCollaborationSession Use Case
 *
 * Orchestrates a user joining a collaboration session.
 * This use case coordinates between domain entities, awareness adapter, and LiveView bridge.
 *
 * Following Clean Architecture:
 * - Depends on interfaces (AwarenessAdapter, LiveViewBridge), not concrete implementations
 * - Handles orchestration and side effects
 * - Uses domain policies for business rules (edit permissions)
 * - Converts between domain types and infrastructure formats
 *
 * @example
 * ```typescript
 * const awarenessAdapter = new YjsAwarenessAdapter(awareness)
 * const liveViewBridge = new PhoenixLiveViewBridge(hook)
 * const useCase = new JoinCollaborationSession(awarenessAdapter, liveViewBridge)
 *
 * const session = CollaborationSession.create('session-123', documentId)
 * const participant = Participant.join(userId, userName, userColor)
 *
 * const updatedSession = await useCase.execute(session, participant)
 * ```
 *
 * @module application/use-cases
 */

import type { AwarenessAdapter } from '../interfaces/awareness-adapter.interface'
import type { LiveViewBridge } from '../interfaces/liveview-bridge.interface'
import { CollaborationSession } from '../../domain/entities/collaboration-session'
import { Participant } from '../../domain/entities/participant'
import { canUserEdit } from '../../domain/policies/edit-permissions'

export class JoinCollaborationSession {
  /**
   * Creates a new JoinCollaborationSession use case
   *
   * @param awarenessAdapter - Adapter for awareness operations (injected)
   * @param liveViewBridge - Bridge for LiveView communication (injected)
   */
  constructor(
    private readonly awarenessAdapter: AwarenessAdapter,
    private readonly liveViewBridge: LiveViewBridge
  ) {}

  /**
   * Execute the join session use case
   *
   * Validates the participant can join, adds them to the session,
   * updates awareness, and broadcasts the join event.
   *
   * @param session - The collaboration session to join
   * @param participant - The participant joining the session
   * @returns Promise that resolves to the updated session
   * @throws Error if participant cannot edit (not authorized)
   */
  async execute(session: CollaborationSession, participant: Participant): Promise<CollaborationSession> {
    // Validate participant can join using domain policy
    if (!canUserEdit(participant)) {
      throw new Error('Participant cannot join session: not authorized to edit')
    }

    // Add participant to session (domain operation)
    const updatedSession = session.addParticipant(participant)

    // Update awareness with user info
    this.awarenessAdapter.setLocalState({
      userId: participant.userId.value,
      userName: participant.userName.value,
      userColor: participant.userColor.hex,
      selection: null
    })

    // Broadcast join event to LiveView
    await this.liveViewBridge.pushEvent('participant-joined', {
      sessionId: session.sessionId,
      userId: participant.userId.value,
      userName: participant.userName.value,
      userColor: participant.userColor.hex
    })

    return updatedSession
  }
}
