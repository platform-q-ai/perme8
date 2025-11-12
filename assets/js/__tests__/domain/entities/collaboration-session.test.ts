/**
 * CollaborationSession Entity Tests
 *
 * Tests for the CollaborationSession entity following TDD principles.
 * Tests are organized by behavior and cover all business rules.
 */

import { describe, test, expect, beforeEach } from 'vitest'
import { CollaborationSession } from '../../../domain/entities/collaboration-session'
import { Participant } from '../../../domain/entities/participant'
import { DocumentId } from '../../../domain/value-objects/document-id'
import { UserId } from '../../../domain/value-objects/user-id'
import { UserName } from '../../../domain/value-objects/user-name'
import { UserColor } from '../../../domain/value-objects/user-color'

describe('CollaborationSession', () => {
  let sessionId: string
  let documentId: DocumentId
  let participant1: Participant
  let participant2: Participant

  beforeEach(() => {
    sessionId = 'session-123'
    documentId = new DocumentId('doc-456')

    participant1 = Participant.join(
      new UserId('user-1'),
      new UserName('John Doe'),
      new UserColor('#FF6B6B')
    )

    participant2 = Participant.join(
      new UserId('user-2'),
      new UserName('Jane Smith'),
      new UserColor('#4ECDC4')
    )
  })

  describe('create factory method', () => {
    test('creates a new session with provided session ID and document ID', () => {
      const session = CollaborationSession.create(sessionId, documentId)

      expect(session.sessionId).toBe(sessionId)
      expect(session.documentId).toBe(documentId)
    })

    test('creates session with empty participants map', () => {
      const session = CollaborationSession.create(sessionId, documentId)

      expect(session.getParticipantCount()).toBe(0)
    })

    test('sets createdAt to current time', () => {
      const before = new Date()
      const session = CollaborationSession.create(sessionId, documentId)
      const after = new Date()

      expect(session.createdAt.getTime()).toBeGreaterThanOrEqual(before.getTime())
      expect(session.createdAt.getTime()).toBeLessThanOrEqual(after.getTime())
    })
  })

  describe('addParticipant method', () => {
    test('adds participant to session', () => {
      const session = CollaborationSession.create(sessionId, documentId)

      const updated = session.addParticipant(participant1)

      expect(updated.hasParticipant(participant1.userId)).toBe(true)
      expect(updated.getParticipantCount()).toBe(1)
    })

    test('returns new session instance (immutability)', () => {
      const session = CollaborationSession.create(sessionId, documentId)

      const updated = session.addParticipant(participant1)

      expect(updated).not.toBe(session)
      expect(session.getParticipantCount()).toBe(0)
    })

    test('can add multiple participants', () => {
      const session = CollaborationSession.create(sessionId, documentId)

      const withFirst = session.addParticipant(participant1)
      const withBoth = withFirst.addParticipant(participant2)

      expect(withBoth.getParticipantCount()).toBe(2)
      expect(withBoth.hasParticipant(participant1.userId)).toBe(true)
      expect(withBoth.hasParticipant(participant2.userId)).toBe(true)
    })

    test('replaces existing participant with same user ID', () => {
      const session = CollaborationSession.create(sessionId, documentId)
      const withParticipant = session.addParticipant(participant1)

      // Create new participant instance with same user ID
      const updatedParticipant = Participant.join(
        new UserId('user-1'),
        new UserName('John Updated'),
        new UserColor('#000000')
      )
      const updated = withParticipant.addParticipant(updatedParticipant)

      expect(updated.getParticipantCount()).toBe(1)
      const retrieved = updated.getParticipant(participant1.userId)
      expect(retrieved?.userName.value).toBe('John Updated')
    })
  })

  describe('removeParticipant method', () => {
    test('removes participant from session', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)

      const updated = session.removeParticipant(participant1.userId)

      expect(updated.hasParticipant(participant1.userId)).toBe(false)
      expect(updated.getParticipantCount()).toBe(0)
    })

    test('returns new session instance (immutability)', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)

      const updated = session.removeParticipant(participant1.userId)

      expect(updated).not.toBe(session)
      expect(session.hasParticipant(participant1.userId)).toBe(true)
    })

    test('does nothing if participant not in session', () => {
      const session = CollaborationSession.create(sessionId, documentId)

      const updated = session.removeParticipant(participant1.userId)

      expect(updated.getParticipantCount()).toBe(0)
    })

    test('only removes specified participant', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)
        .addParticipant(participant2)

      const updated = session.removeParticipant(participant1.userId)

      expect(updated.hasParticipant(participant1.userId)).toBe(false)
      expect(updated.hasParticipant(participant2.userId)).toBe(true)
      expect(updated.getParticipantCount()).toBe(1)
    })
  })

  describe('deactivateParticipant method', () => {
    test('marks participant as inactive', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)

      const updated = session.deactivateParticipant(participant1.userId)

      const participant = updated.getParticipant(participant1.userId)
      expect(participant).not.toBeNull()
      expect(participant?.isActive).toBe(false)
    })

    test('returns new session instance (immutability)', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)

      const updated = session.deactivateParticipant(participant1.userId)

      expect(updated).not.toBe(session)
      const originalParticipant = session.getParticipant(participant1.userId)
      expect(originalParticipant?.isActive).toBe(true)
    })

    test('keeps participant in session (does not remove)', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)

      const updated = session.deactivateParticipant(participant1.userId)

      expect(updated.hasParticipant(participant1.userId)).toBe(true)
      expect(updated.getParticipantCount()).toBe(1)
    })

    test('does nothing if participant not in session', () => {
      const session = CollaborationSession.create(sessionId, documentId)

      const updated = session.deactivateParticipant(participant1.userId)

      expect(updated.getParticipantCount()).toBe(0)
    })
  })

  describe('getParticipant method', () => {
    test('returns participant when exists', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)

      const retrieved = session.getParticipant(participant1.userId)

      expect(retrieved).not.toBeNull()
      expect(retrieved?.userId).toBe(participant1.userId)
    })

    test('returns null when participant does not exist', () => {
      const session = CollaborationSession.create(sessionId, documentId)

      const retrieved = session.getParticipant(participant1.userId)

      expect(retrieved).toBeNull()
    })
  })

  describe('getActiveParticipants method', () => {
    test('returns only active participants', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)
        .addParticipant(participant2)
        .deactivateParticipant(participant2.userId)

      const active = session.getActiveParticipants()

      expect(active).toHaveLength(1)
      expect(active[0].userId).toBe(participant1.userId)
    })

    test('returns empty array when no participants', () => {
      const session = CollaborationSession.create(sessionId, documentId)

      const active = session.getActiveParticipants()

      expect(active).toHaveLength(0)
    })

    test('returns empty array when all participants inactive', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)
        .deactivateParticipant(participant1.userId)

      const active = session.getActiveParticipants()

      expect(active).toHaveLength(0)
    })

    test('returns all participants when all active', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)
        .addParticipant(participant2)

      const active = session.getActiveParticipants()

      expect(active).toHaveLength(2)
    })
  })

  describe('hasParticipant method', () => {
    test('returns true when participant exists', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)

      expect(session.hasParticipant(participant1.userId)).toBe(true)
    })

    test('returns false when participant does not exist', () => {
      const session = CollaborationSession.create(sessionId, documentId)

      expect(session.hasParticipant(participant1.userId)).toBe(false)
    })

    test('returns true even for inactive participants', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)
        .deactivateParticipant(participant1.userId)

      expect(session.hasParticipant(participant1.userId)).toBe(true)
    })
  })

  describe('getParticipantCount method', () => {
    test('returns zero for empty session', () => {
      const session = CollaborationSession.create(sessionId, documentId)

      expect(session.getParticipantCount()).toBe(0)
    })

    test('returns correct count with participants', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)
        .addParticipant(participant2)

      expect(session.getParticipantCount()).toBe(2)
    })

    test('counts inactive participants', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)
        .addParticipant(participant2)
        .deactivateParticipant(participant2.userId)

      expect(session.getParticipantCount()).toBe(2)
    })

    test('decrements when participant removed', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)
        .addParticipant(participant2)
        .removeParticipant(participant1.userId)

      expect(session.getParticipantCount()).toBe(1)
    })
  })

  describe('immutability', () => {
    test('sessionId property is readonly', () => {
      const session = CollaborationSession.create(sessionId, documentId)

      // @ts-expect-error - sessionId is readonly
      session.sessionId = 'different'
    })

    test('documentId property is readonly', () => {
      const session = CollaborationSession.create(sessionId, documentId)

      // @ts-expect-error - documentId is readonly
      session.documentId = new DocumentId('different')
    })

    test('createdAt property is readonly', () => {
      const session = CollaborationSession.create(sessionId, documentId)

      // @ts-expect-error - createdAt is readonly
      session.createdAt = new Date()
    })

    test('cannot modify participants map directly', () => {
      const session = CollaborationSession.create(sessionId, documentId)

      // participants should be private/readonly
      // TypeScript compile-time check
      // @ts-expect-error - participants is private
      session.participants = new Map()
    })
  })

  describe('business rules', () => {
    test('session must have a valid session ID', () => {
      expect(() => {
        CollaborationSession.create('', documentId)
      }).toThrow('Session ID cannot be empty')
    })

    test('session must have a valid document ID', () => {
      expect(() => {
        CollaborationSession.create(sessionId, new DocumentId(''))
      }).toThrow('Document ID cannot be empty')
    })

    test('adding participant uses user ID as map key', () => {
      const session = CollaborationSession.create(sessionId, documentId)
        .addParticipant(participant1)

      const retrieved = session.getParticipant(participant1.userId)
      expect(retrieved?.userId.value).toBe('user-1')
    })
  })
})
