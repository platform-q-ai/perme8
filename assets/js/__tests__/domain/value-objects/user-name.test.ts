import { describe, test, expect } from 'vitest'
import { UserName } from '../../../domain/value-objects/user-name'

describe('UserName', () => {
  describe('constructor', () => {
    test('creates UserName with valid string', () => {
      const name = new UserName('John Doe')

      expect(name.value).toBe('John Doe')
    })

    test('throws error for empty string', () => {
      expect(() => new UserName('')).toThrow('User name cannot be empty')
    })

    test('throws error for whitespace-only string', () => {
      expect(() => new UserName('   ')).toThrow('User name cannot be empty')
    })

    test('throws error for null', () => {
      expect(() => new UserName(null as any)).toThrow('User name cannot be empty')
    })

    test('throws error for undefined', () => {
      expect(() => new UserName(undefined as any)).toThrow('User name cannot be empty')
    })

    test('throws error for name exceeding max length', () => {
      const longName = 'a'.repeat(101)
      expect(() => new UserName(longName)).toThrow('User name cannot exceed 100 characters')
    })

    test('accepts name at max length boundary', () => {
      const maxLengthName = 'a'.repeat(100)

      expect(() => new UserName(maxLengthName)).not.toThrow()
    })

    test('trims whitespace from name', () => {
      const name = new UserName('  John Doe  ')

      expect(name.value).toBe('John Doe')
    })
  })

  describe('equals', () => {
    test('returns true for same name value', () => {
      const name1 = new UserName('John Doe')
      const name2 = new UserName('John Doe')

      expect(name1.equals(name2)).toBe(true)
    })

    test('returns false for different name values', () => {
      const name1 = new UserName('John Doe')
      const name2 = new UserName('Jane Smith')

      expect(name1.equals(name2)).toBe(false)
    })

    test('returns true when compared with itself', () => {
      const name = new UserName('John Doe')

      expect(name.equals(name)).toBe(true)
    })

    test('returns true for trimmed vs untrimmed names', () => {
      const name1 = new UserName('John Doe')
      const name2 = new UserName('  John Doe  ')

      expect(name1.equals(name2)).toBe(true)
    })
  })

  describe('toString', () => {
    test('returns the name value', () => {
      const name = new UserName('John Doe')

      expect(name.toString()).toBe('John Doe')
    })
  })

  describe('immutability', () => {
    test('creates a new instance with same value when accessed', () => {
      const name = new UserName('John Doe')

      // Value is immutable - TypeScript prevents modification at compile time
      expect(name.value).toBe('John Doe')

      // Creating a new instance doesn't affect the original
      const name2 = new UserName('Jane Smith')
      expect(name.value).toBe('John Doe')
      expect(name2.value).toBe('Jane Smith')
    })
  })
})
