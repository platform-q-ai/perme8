/**
 * Tests for JoinCollaborationSession use case
 *
 * Following TDD (RED-GREEN-REFACTOR):
 * - RED: These tests are written FIRST and will FAIL
 * - GREEN: Implementation will be written to make them pass
 * - REFACTOR: Code will be cleaned up while keeping tests green
 */

import { describe, test, expect, vi, beforeEach } from 'vitest'
import { JoinCollaborationSession } from '../../../application/use-cases/join-collaboration-session'
import type { AwarenessAdapter } from '../../../application/interfaces/awareness-adapter.interface'
import type { LiveViewBridge } from '../../../application/interfaces/liveview-bridge.interface'
import { CollaborationSession } from '../../../domain/entities/collaboration-session'
import { Participant } from '../../../domain/entities/participant'
import { DocumentId } from '../../../domain/value-objects/document-id'
import { UserId } from '../../../domain/value-objects/user-id'
import { UserName } from '../../../domain/value-objects/user-name'
import { UserColor } from '../../../domain/value-objects/user-color'

describe('JoinCollaborationSession', () => {
  let mockAwarenessAdapter: AwarenessAdapter
  let mockLiveViewBridge: LiveViewBridge
  let useCase: JoinCollaborationSession
  let session: CollaborationSession
  let participant: Participant

  beforeEach(() => {
    // Mock AwarenessAdapter
    mockAwarenessAdapter = {
      setLocalState: vi.fn(),
      onAwarenessChange: vi.fn(),
      encodeUpdate: vi.fn(),
      applyUpdate: vi.fn()
    }

    // Mock LiveViewBridge
    mockLiveViewBridge = {
      pushEvent: vi.fn().mockResolvedValue(undefined),
      handleEvent: vi.fn()
    }

    // Create use case with mocked dependencies
    useCase = new JoinCollaborationSession(mockAwarenessAdapter, mockLiveViewBridge)

    // Create test session and participant
    const documentId = new DocumentId('doc-123')
    session = CollaborationSession.create('session-123', documentId)

    const userId = new UserId('user-456')
    const userName = new UserName('John Doe')
    const userColor = new UserColor('#FF6B6B')
    participant = Participant.join(userId, userName, userColor)
  })

  describe('execute', () => {
    test('adds participant to session', async () => {
      const result = await useCase.execute(session, participant)

      expect(result.hasParticipant(participant.userId)).toBe(true)
    })

    test('updates awareness with user info', async () => {
      await useCase.execute(session, participant)

      expect(mockAwarenessAdapter.setLocalState).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'user-456',
          userName: 'John Doe',
          userColor: '#FF6B6B'
        })
      )
    })

    test('broadcasts join event to LiveView', async () => {
      await useCase.execute(session, participant)

      expect(mockLiveViewBridge.pushEvent).toHaveBeenCalledWith(
        'participant-joined',
        expect.objectContaining({
          sessionId: 'session-123',
          userId: 'user-456',
          userName: 'John Doe'
        })
      )
    })

    test('returns updated session with participant', async () => {
      const result = await useCase.execute(session, participant)

      expect(result).not.toBe(session) // New instance (immutability)
      expect(result.getParticipant(participant.userId)).toBeDefined()
      expect(result.getParticipantCount()).toBe(1)
    })

    test('allows participant to rejoin existing session', async () => {
      // First join
      const firstJoin = await useCase.execute(session, participant)

      // Rejoin (participant already in session)
      const secondJoin = await useCase.execute(firstJoin, participant)

      expect(secondJoin.hasParticipant(participant.userId)).toBe(true)
      expect(secondJoin.getParticipantCount()).toBe(1) // Still just one participant
    })

    test('handles multiple participants', async () => {
      // Add first participant
      const withFirst = await useCase.execute(session, participant)

      // Add second participant
      const userId2 = new UserId('user-789')
      const userName2 = new UserName('Jane Smith')
      const userColor2 = new UserColor('#4ECDC4')
      const participant2 = Participant.join(userId2, userName2, userColor2)

      const withSecond = await useCase.execute(withFirst, participant2)

      expect(withSecond.getParticipantCount()).toBe(2)
      expect(withSecond.hasParticipant(participant.userId)).toBe(true)
      expect(withSecond.hasParticipant(participant2.userId)).toBe(true)
    })

    test('uses canUserEdit policy from domain layer', async () => {
      // Participant should be active to pass the policy
      expect(participant.isActive).toBe(true)

      await useCase.execute(session, participant)

      // Should not throw (participant is active)
    })

    test('throws error if participant cannot edit', async () => {
      // Create inactive participant
      const inactiveParticipant = participant.deactivate()

      expect(inactiveParticipant.isActive).toBe(false)

      // Should throw because inactive participants cannot edit
      await expect(useCase.execute(session, inactiveParticipant)).rejects.toThrow(
        'Participant cannot join session: not authorized to edit'
      )
    })

    test('updates awareness with null selection initially', async () => {
      await useCase.execute(session, participant)

      expect(mockAwarenessAdapter.setLocalState).toHaveBeenCalledWith(
        expect.objectContaining({
          selection: null
        })
      )
    })

    test('awaits LiveView broadcast before completing', async () => {
      let pushEventResolved = false
      vi.mocked(mockLiveViewBridge.pushEvent).mockImplementation(async () => {
        await new Promise(resolve => setTimeout(resolve, 10))
        pushEventResolved = true
      })

      await useCase.execute(session, participant)

      expect(pushEventResolved).toBe(true)
    })
  })
})
