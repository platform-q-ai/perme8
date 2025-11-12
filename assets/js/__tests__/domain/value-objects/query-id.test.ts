import { describe, test, expect } from 'vitest'
import { QueryId } from '../../../domain/value-objects/query-id'

describe('QueryId', () => {
  describe('constructor', () => {
    test('creates query id with valid string', () => {
      const queryId = new QueryId('query_123')

      expect(queryId.value).toBe('query_123')
    })

    test('throws error for empty string', () => {
      expect(() => new QueryId('')).toThrow('Query ID cannot be empty')
    })

    test('throws error for whitespace-only string', () => {
      expect(() => new QueryId('   ')).toThrow('Query ID cannot be empty')
    })
  })

  describe('generate', () => {
    test('generates unique query id', () => {
      const queryId1 = QueryId.generate()
      const queryId2 = QueryId.generate()

      expect(queryId1.value).not.toBe(queryId2.value)
    })

    test('generated id starts with query_ prefix', () => {
      const queryId = QueryId.generate()

      expect(queryId.value).toMatch(/^query_/)
    })

    test('generated id contains timestamp', () => {
      const beforeTimestamp = Date.now()
      const queryId = QueryId.generate()
      const afterTimestamp = Date.now()

      // Extract timestamp from generated ID (format: query_{timestamp}_{random})
      const parts = queryId.value.split('_')
      const timestamp = parseInt(parts[1])

      expect(timestamp).toBeGreaterThanOrEqual(beforeTimestamp)
      expect(timestamp).toBeLessThanOrEqual(afterTimestamp)
    })

    test('generated id contains random suffix', () => {
      const queryId = QueryId.generate()

      // Should have format: query_{timestamp}_{random}
      const parts = queryId.value.split('_')
      expect(parts.length).toBe(3)
      expect(parts[2]).toMatch(/^[a-z0-9]+$/)
    })
  })

  describe('equals', () => {
    test('returns true for same id value', () => {
      const queryId1 = new QueryId('query_123')
      const queryId2 = new QueryId('query_123')

      expect(queryId1.equals(queryId2)).toBe(true)
    })

    test('returns false for different id values', () => {
      const queryId1 = new QueryId('query_123')
      const queryId2 = new QueryId('query_456')

      expect(queryId1.equals(queryId2)).toBe(false)
    })
  })

  describe('toString', () => {
    test('returns string representation', () => {
      const queryId = new QueryId('query_123')

      expect(queryId.toString()).toBe('query_123')
    })
  })
})
