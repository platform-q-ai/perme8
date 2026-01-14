import { describe, test, expect } from 'vitest'
import { UserId } from '../../../domain/value-objects/user-id'

describe('UserId', () => {
  describe('constructor', () => {
    test('creates UserId with valid string', () => {
      const id = new UserId('user-123')

      expect(id.value).toBe('user-123')
    })

    test('throws error for empty string', () => {
      expect(() => new UserId('')).toThrow('User ID cannot be empty')
    })

    test('throws error for whitespace-only string', () => {
      expect(() => new UserId('   ')).toThrow('User ID cannot be empty')
    })

    test('throws error for null', () => {
      expect(() => new UserId(null as any)).toThrow('User ID cannot be empty')
    })

    test('throws error for undefined', () => {
      expect(() => new UserId(undefined as any)).toThrow('User ID cannot be empty')
    })
  })

  describe('equals', () => {
    test('returns true for same ID value', () => {
      const id1 = new UserId('user-123')
      const id2 = new UserId('user-123')

      expect(id1.equals(id2)).toBe(true)
    })

    test('returns false for different ID values', () => {
      const id1 = new UserId('user-123')
      const id2 = new UserId('user-456')

      expect(id1.equals(id2)).toBe(false)
    })

    test('returns true when compared with itself', () => {
      const id = new UserId('user-123')

      expect(id.equals(id)).toBe(true)
    })
  })

  describe('toString', () => {
    test('returns the ID value', () => {
      const id = new UserId('user-123')

      expect(id.toString()).toBe('user-123')
    })
  })

  describe('immutability', () => {
    test('creates a new instance with same value when accessed', () => {
      const id = new UserId('user-123')

      // Value is immutable - TypeScript prevents modification at compile time
      expect(id.value).toBe('user-123')

      // Creating a new instance doesn't affect the original
      const id2 = new UserId('user-456')
      expect(id.value).toBe('user-123')
      expect(id2.value).toBe('user-456')
    })
  })
})
