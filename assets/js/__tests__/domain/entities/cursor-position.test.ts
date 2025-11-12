import { describe, test, expect, beforeEach } from 'vitest'
import { CursorPosition } from '../../../domain/entities/cursor-position'
import { UserId } from '../../../domain/value-objects/user-id'

describe('CursorPosition', () => {
  let userId: UserId

  beforeEach(() => {
    userId = new UserId('user-123')
  })

  describe('create', () => {
    test('creates CursorPosition with valid data', () => {
      const cursor = CursorPosition.create(userId, 10)

      expect(cursor.userId).toBe(userId)
      expect(cursor.position).toBe(10)
      expect(cursor.timestamp).toBeInstanceOf(Date)
    })

    test('creates CursorPosition at position zero', () => {
      const cursor = CursorPosition.create(userId, 0)

      expect(cursor.position).toBe(0)
    })

    test('throws error for negative position', () => {
      expect(() => CursorPosition.create(userId, -1)).toThrow('Cursor position must be non-negative')
    })

    test('sets timestamp to current time', () => {
      const beforeCreate = Date.now()
      const cursor = CursorPosition.create(userId, 10)
      const afterCreate = Date.now()

      const timestamp = cursor.timestamp.getTime()
      expect(timestamp).toBeGreaterThanOrEqual(beforeCreate)
      expect(timestamp).toBeLessThanOrEqual(afterCreate)
    })
  })

  describe('constructor', () => {
    test('creates CursorPosition with explicit timestamp', () => {
      const timestamp = new Date('2025-11-12T10:00:00Z')
      const cursor = new CursorPosition(userId, 10, timestamp)

      expect(cursor.userId).toBe(userId)
      expect(cursor.position).toBe(10)
      expect(cursor.timestamp).toBe(timestamp)
    })

    test('throws error for negative position', () => {
      expect(() => new CursorPosition(userId, -5, new Date())).toThrow('Cursor position must be non-negative')
    })

    test('allows zero position', () => {
      const cursor = new CursorPosition(userId, 0, new Date())

      expect(cursor.position).toBe(0)
    })

    test('allows large position values', () => {
      const cursor = new CursorPosition(userId, 10000, new Date())

      expect(cursor.position).toBe(10000)
    })
  })

  describe('isStale', () => {
    test('returns false for recent cursor', () => {
      const cursor = CursorPosition.create(userId, 10)

      expect(cursor.isStale(5000)).toBe(false)
    })

    test('returns true for old cursor', () => {
      const oldTimestamp = new Date(Date.now() - 10000) // 10 seconds ago
      const cursor = new CursorPosition(userId, 10, oldTimestamp)

      expect(cursor.isStale(5000)).toBe(true)
    })

    test('returns false when exactly at max age', () => {
      const timestamp = new Date(Date.now() - 5000) // Exactly 5 seconds ago
      const cursor = new CursorPosition(userId, 10, timestamp)

      // Should not be stale at exactly the max age (boundary inclusive)
      expect(cursor.isStale(5000)).toBe(false)
    })

    test('returns true when just over max age', () => {
      const timestamp = new Date(Date.now() - 5001) // Just over 5 seconds ago
      const cursor = new CursorPosition(userId, 10, timestamp)

      expect(cursor.isStale(5000)).toBe(true)
    })

    test('handles zero max age', () => {
      // With 0ms max age, only cursors with future timestamps would not be stale
      // Create cursor in the past to ensure it's stale
      const pastTimestamp = new Date(Date.now() - 1)
      const cursor = new CursorPosition(userId, 10, pastTimestamp)

      expect(cursor.isStale(0)).toBe(true)
    })

    test('handles very large max age', () => {
      const oldTimestamp = new Date(Date.now() - 1000000) // Very old
      const cursor = new CursorPosition(userId, 10, oldTimestamp)

      expect(cursor.isStale(10000000)).toBe(false)
    })

    test('returns false for future timestamp', () => {
      // Edge case: cursor with future timestamp (clock skew)
      const futureTimestamp = new Date(Date.now() + 5000)
      const cursor = new CursorPosition(userId, 10, futureTimestamp)

      expect(cursor.isStale(1000)).toBe(false)
    })
  })

  describe('immutability', () => {
    test('creates immutable entity', () => {
      const timestamp = new Date('2025-11-12T10:00:00Z')
      const cursor = new CursorPosition(userId, 10, timestamp)

      // Properties are readonly - TypeScript prevents modification at compile time
      expect(cursor.userId).toBe(userId)
      expect(cursor.position).toBe(10)
      expect(cursor.timestamp).toBe(timestamp)

      // Creating a new cursor doesn't affect the original
      const userId2 = new UserId('user-456')
      const cursor2 = CursorPosition.create(userId2, 20)

      expect(cursor.userId).toBe(userId)
      expect(cursor.position).toBe(10)
      expect(cursor2.userId).toBe(userId2)
      expect(cursor2.position).toBe(20)
    })
  })

  describe('integration with UserId', () => {
    test('preserves UserId value object', () => {
      const userId1 = new UserId('user-123')
      const userId2 = new UserId('user-123')

      const cursor1 = CursorPosition.create(userId1, 10)
      const cursor2 = CursorPosition.create(userId2, 10)

      expect(cursor1.userId.equals(cursor2.userId)).toBe(true)
    })

    test('distinguishes different users', () => {
      const userId1 = new UserId('user-123')
      const userId2 = new UserId('user-456')

      const cursor1 = CursorPosition.create(userId1, 10)
      const cursor2 = CursorPosition.create(userId2, 10)

      expect(cursor1.userId.equals(cursor2.userId)).toBe(false)
    })
  })
})
