/**
 * Participant Entity Tests
 *
 * Tests for the Participant entity following TDD principles.
 * Tests are organized by behavior and cover all business rules.
 */

import { describe, test, expect, beforeEach } from 'vitest'
import { Participant } from '../../../domain/entities/participant'
import { UserId } from '../../../domain/value-objects/user-id'
import { UserName } from '../../../domain/value-objects/user-name'
import { UserColor } from '../../../domain/value-objects/user-color'

describe('Participant', () => {
  let userId: UserId
  let userName: UserName
  let userColor: UserColor

  beforeEach(() => {
    userId = new UserId('user-123')
    userName = new UserName('John Doe')
    userColor = new UserColor('#FF6B6B')
  })

  describe('join factory method', () => {
    test('creates a new participant with provided values', () => {
      const participant = Participant.join(userId, userName, userColor)

      expect(participant.userId).toBe(userId)
      expect(participant.userName).toBe(userName)
      expect(participant.userColor).toBe(userColor)
      expect(participant.isActive).toBe(true)
    })

    test('sets joinedAt to current time', () => {
      const before = new Date()
      const participant = Participant.join(userId, userName, userColor)
      const after = new Date()

      expect(participant.joinedAt.getTime()).toBeGreaterThanOrEqual(before.getTime())
      expect(participant.joinedAt.getTime()).toBeLessThanOrEqual(after.getTime())
    })

    test('creates active participant by default', () => {
      const participant = Participant.join(userId, userName, userColor)

      expect(participant.isActive).toBe(true)
    })

    test('creates different instances for same user', () => {
      const participant1 = Participant.join(userId, userName, userColor)
      const participant2 = Participant.join(userId, userName, userColor)

      expect(participant1).not.toBe(participant2)
    })
  })

  describe('deactivate method', () => {
    test('returns new participant with isActive set to false', () => {
      const participant = Participant.join(userId, userName, userColor)

      const deactivated = participant.deactivate()

      expect(deactivated.isActive).toBe(false)
      expect(participant.isActive).toBe(true) // Original unchanged
    })

    test('preserves all other properties', () => {
      const participant = Participant.join(userId, userName, userColor)

      const deactivated = participant.deactivate()

      expect(deactivated.userId).toBe(participant.userId)
      expect(deactivated.userName).toBe(participant.userName)
      expect(deactivated.userColor).toBe(participant.userColor)
      expect(deactivated.joinedAt).toEqual(participant.joinedAt)
    })

    test('returns new instance (immutability)', () => {
      const participant = Participant.join(userId, userName, userColor)

      const deactivated = participant.deactivate()

      expect(deactivated).not.toBe(participant)
    })

    test('can deactivate already deactivated participant', () => {
      const participant = Participant.join(userId, userName, userColor)
      const deactivated1 = participant.deactivate()

      const deactivated2 = deactivated1.deactivate()

      expect(deactivated2.isActive).toBe(false)
      expect(deactivated2).not.toBe(deactivated1)
    })
  })

  describe('immutability', () => {
    test('userId property is readonly', () => {
      const participant = Participant.join(userId, userName, userColor)

      // TypeScript compile-time check (would fail if not readonly)
      // @ts-expect-error - userId is readonly
      participant.userId = new UserId('different')
    })

    test('userName property is readonly', () => {
      const participant = Participant.join(userId, userName, userColor)

      // @ts-expect-error - userName is readonly
      participant.userName = new UserName('Different Name')
    })

    test('userColor property is readonly', () => {
      const participant = Participant.join(userId, userName, userColor)

      // @ts-expect-error - userColor is readonly
      participant.userColor = new UserColor('#000000')
    })

    test('joinedAt property is readonly', () => {
      const participant = Participant.join(userId, userName, userColor)

      // @ts-expect-error - joinedAt is readonly
      participant.joinedAt = new Date()
    })

    test('isActive property is readonly', () => {
      const participant = Participant.join(userId, userName, userColor)

      // @ts-expect-error - isActive is readonly
      participant.isActive = false
    })
  })

  describe('business rules', () => {
    test('participant must have a valid user ID', () => {
      expect(() => {
        new UserId('')
      }).toThrow('User ID cannot be empty')
    })

    test('participant must have a valid user name', () => {
      expect(() => {
        new UserName('')
      }).toThrow('User name cannot be empty')
    })

    test('participant must have a valid user color', () => {
      expect(() => {
        new UserColor('invalid')
      }).toThrow('Invalid hex color')
    })

    test('newly joined participant is always active', () => {
      const participant = Participant.join(userId, userName, userColor)

      expect(participant.isActive).toBe(true)
    })
  })
})
