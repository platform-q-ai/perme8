/**
 * Edit Permissions Policy Tests
 *
 * Tests for pure policy functions that determine edit permissions
 * in collaboration sessions.
 */

import { describe, test, expect, beforeEach } from 'vitest'
import {
  canUserEdit,
  canParticipantJoin,
  isSessionFull
} from '../../../domain/policies/edit-permissions'
import { Participant } from '../../../domain/entities/participant'
import { UserId } from '../../../domain/value-objects/user-id'
import { UserName } from '../../../domain/value-objects/user-name'
import { UserColor } from '../../../domain/value-objects/user-color'

describe('Edit Permissions Policy', () => {
  let activeParticipant: Participant
  let inactiveParticipant: Participant

  beforeEach(() => {
    const userId = new UserId('user-123')
    const userName = new UserName('John Doe')
    const userColor = new UserColor('#FF6B6B')

    activeParticipant = Participant.join(userId, userName, userColor)
    inactiveParticipant = activeParticipant.deactivate()
  })

  describe('canUserEdit', () => {
    test('returns true for active participant', () => {
      const canEdit = canUserEdit(activeParticipant)

      expect(canEdit).toBe(true)
    })

    test('returns false for inactive participant', () => {
      const canEdit = canUserEdit(inactiveParticipant)

      expect(canEdit).toBe(false)
    })

    test('pure function - does not modify participant', () => {
      const originalActive = activeParticipant.isActive

      canUserEdit(activeParticipant)

      expect(activeParticipant.isActive).toBe(originalActive)
    })

    test('consistent results for same participant', () => {
      const result1 = canUserEdit(activeParticipant)
      const result2 = canUserEdit(activeParticipant)

      expect(result1).toBe(result2)
    })
  })

  describe('canParticipantJoin', () => {
    test('returns true when session has space', () => {
      const participants = new Map<string, Participant>([
        ['user-1', activeParticipant]
      ])
      const newParticipant = Participant.join(
        new UserId('user-2'),
        new UserName('Jane Smith'),
        new UserColor('#4ECDC4')
      )

      const canJoin = canParticipantJoin(participants, newParticipant, 5)

      expect(canJoin).toBe(true)
    })

    test('returns false when session is full', () => {
      const participants = new Map<string, Participant>([
        ['user-1', activeParticipant],
        ['user-2', Participant.join(
          new UserId('user-2'),
          new UserName('Jane'),
          new UserColor('#4ECDC4')
        )],
        ['user-3', Participant.join(
          new UserId('user-3'),
          new UserName('Bob'),
          new UserColor('#95E1D3')
        )]
      ])
      const newParticipant = Participant.join(
        new UserId('user-4'),
        new UserName('Alice'),
        new UserColor('#F38181')
      )

      const canJoin = canParticipantJoin(participants, newParticipant, 3)

      expect(canJoin).toBe(false)
    })

    test('returns true when participant already exists (rejoin)', () => {
      const participants = new Map<string, Participant>([
        ['user-123', activeParticipant]
      ])
      const rejoiningParticipant = Participant.join(
        new UserId('user-123'),
        new UserName('John Doe'),
        new UserColor('#FF6B6B')
      )

      const canJoin = canParticipantJoin(participants, rejoiningParticipant, 5)

      expect(canJoin).toBe(true)
    })

    test('pure function - does not modify participants map', () => {
      const participants = new Map<string, Participant>([
        ['user-1', activeParticipant]
      ])
      const originalSize = participants.size
      const newParticipant = Participant.join(
        new UserId('user-2'),
        new UserName('Jane'),
        new UserColor('#4ECDC4')
      )

      canParticipantJoin(participants, newParticipant, 5)

      expect(participants.size).toBe(originalSize)
    })

    test('returns true when exactly at capacity but participant exists', () => {
      const participants = new Map<string, Participant>([
        ['user-123', activeParticipant]
      ])
      const rejoiningParticipant = Participant.join(
        new UserId('user-123'),
        new UserName('John'),
        new UserColor('#FF6B6B')
      )

      const canJoin = canParticipantJoin(participants, rejoiningParticipant, 1)

      expect(canJoin).toBe(true)
    })
  })

  describe('isSessionFull', () => {
    test('returns false when session has space', () => {
      const participants = new Map<string, Participant>([
        ['user-1', activeParticipant]
      ])

      const full = isSessionFull(participants, 5)

      expect(full).toBe(false)
    })

    test('returns true when session is at max capacity', () => {
      const participants = new Map<string, Participant>([
        ['user-1', activeParticipant],
        ['user-2', Participant.join(
          new UserId('user-2'),
          new UserName('Jane'),
          new UserColor('#4ECDC4')
        )],
        ['user-3', Participant.join(
          new UserId('user-3'),
          new UserName('Bob'),
          new UserColor('#95E1D3')
        )]
      ])

      const full = isSessionFull(participants, 3)

      expect(full).toBe(true)
    })

    test('returns true when session exceeds capacity', () => {
      const participants = new Map<string, Participant>([
        ['user-1', activeParticipant],
        ['user-2', Participant.join(
          new UserId('user-2'),
          new UserName('Jane'),
          new UserColor('#4ECDC4')
        )],
        ['user-3', Participant.join(
          new UserId('user-3'),
          new UserName('Bob'),
          new UserColor('#95E1D3')
        )]
      ])

      const full = isSessionFull(participants, 2)

      expect(full).toBe(true)
    })

    test('returns false for empty session', () => {
      const participants = new Map<string, Participant>()

      const full = isSessionFull(participants, 5)

      expect(full).toBe(false)
    })

    test('pure function - does not modify participants map', () => {
      const participants = new Map<string, Participant>([
        ['user-1', activeParticipant]
      ])
      const originalSize = participants.size

      isSessionFull(participants, 5)

      expect(participants.size).toBe(originalSize)
    })

    test('counts inactive participants toward capacity', () => {
      const participants = new Map<string, Participant>([
        ['user-1', activeParticipant],
        ['user-2', inactiveParticipant]
      ])

      const full = isSessionFull(participants, 2)

      expect(full).toBe(true)
    })
  })

  describe('policy composition', () => {
    test('active participant in non-full session can edit', () => {
      const participants = new Map<string, Participant>([
        ['user-123', activeParticipant]
      ])

      const canEdit = canUserEdit(activeParticipant)
      const sessionFull = isSessionFull(participants, 5)

      expect(canEdit).toBe(true)
      expect(sessionFull).toBe(false)
    })

    test('inactive participant cannot edit even if session not full', () => {
      const participants = new Map<string, Participant>([
        ['user-123', inactiveParticipant]
      ])

      const canEdit = canUserEdit(inactiveParticipant)
      const sessionFull = isSessionFull(participants, 5)

      expect(canEdit).toBe(false)
      expect(sessionFull).toBe(false)
    })
  })
})
