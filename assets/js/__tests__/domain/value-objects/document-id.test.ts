import { describe, test, expect } from 'vitest'
import { DocumentId } from '../../../domain/value-objects/document-id'

describe('DocumentId', () => {
  describe('constructor', () => {
    test('creates DocumentId with valid string', () => {
      const id = new DocumentId('doc-123')

      expect(id.value).toBe('doc-123')
    })

    test('creates DocumentId with UUID format', () => {
      const uuid = '550e8400-e29b-41d4-a716-446655440000'
      const id = new DocumentId(uuid)

      expect(id.value).toBe(uuid)
    })

    test('throws error for empty string', () => {
      expect(() => new DocumentId('')).toThrow('Document ID cannot be empty')
    })

    test('throws error for whitespace-only string', () => {
      expect(() => new DocumentId('   ')).toThrow('Document ID cannot be empty')
    })

    test('throws error for null', () => {
      expect(() => new DocumentId(null as any)).toThrow('Document ID cannot be empty')
    })

    test('throws error for undefined', () => {
      expect(() => new DocumentId(undefined as any)).toThrow('Document ID cannot be empty')
    })
  })

  describe('equals', () => {
    test('returns true for same ID value', () => {
      const id1 = new DocumentId('doc-123')
      const id2 = new DocumentId('doc-123')

      expect(id1.equals(id2)).toBe(true)
    })

    test('returns false for different ID values', () => {
      const id1 = new DocumentId('doc-123')
      const id2 = new DocumentId('doc-456')

      expect(id1.equals(id2)).toBe(false)
    })

    test('returns true when compared with itself', () => {
      const id = new DocumentId('doc-123')

      expect(id.equals(id)).toBe(true)
    })
  })

  describe('toString', () => {
    test('returns the ID value', () => {
      const id = new DocumentId('doc-123')

      expect(id.toString()).toBe('doc-123')
    })
  })

  describe('immutability', () => {
    test('creates a new instance with same value when accessed', () => {
      const id = new DocumentId('doc-123')

      // Value is immutable - TypeScript prevents modification at compile time
      expect(id.value).toBe('doc-123')

      // Creating a new instance doesn't affect the original
      const id2 = new DocumentId('doc-456')
      expect(id.value).toBe('doc-123')
      expect(id2.value).toBe('doc-456')
    })
  })
})
