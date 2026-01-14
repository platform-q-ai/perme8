import { describe, test, expect } from 'vitest'
import { MentionPattern } from '../../../domain/value-objects/mention-pattern'

describe('MentionPattern', () => {
  describe('constructor', () => {
    test('creates mention pattern with valid pattern', () => {
      const pattern = new MentionPattern('@j')

      expect(pattern.value).toBe('@j')
    })

    test('throws error for empty pattern', () => {
      expect(() => new MentionPattern('')).toThrow('Mention pattern cannot be empty')
    })

    test('throws error for pattern without @ symbol', () => {
      expect(() => new MentionPattern('j')).toThrow('Mention pattern must start with @')
    })
  })

  describe('matches', () => {
    test('returns true for text containing @j mention', () => {
      const pattern = new MentionPattern('@j')

      expect(pattern.matches('@j what is TypeScript?')).toBe(true)
    })

    test('returns false for text without @j mention', () => {
      const pattern = new MentionPattern('@j')

      expect(pattern.matches('hello world')).toBe(false)
    })

    test('returns false for partial @ symbol', () => {
      const pattern = new MentionPattern('@j')

      expect(pattern.matches('@ j question')).toBe(false)
    })

    test('handles case insensitive matching', () => {
      const pattern = new MentionPattern('@j')

      expect(pattern.matches('@J what is TypeScript?')).toBe(true)
    })
  })

  describe('extract', () => {
    test('extracts question from @j mention', () => {
      const pattern = new MentionPattern('@j')

      const result = pattern.extract('@j what is TypeScript?')

      expect(result).toBe('what is TypeScript?')
    })

    test('returns null when no mention found', () => {
      const pattern = new MentionPattern('@j')

      const result = pattern.extract('hello world')

      expect(result).toBeNull()
    })

    test('trims whitespace from extracted question', () => {
      const pattern = new MentionPattern('@j')

      const result = pattern.extract('@j    what is TypeScript?   ')

      expect(result).toBe('what is TypeScript?')
    })

    test('returns null for empty question', () => {
      const pattern = new MentionPattern('@j')

      const result = pattern.extract('@j   ')

      expect(result).toBeNull()
    })
  })

  describe('findInText', () => {
    test('finds mention at start of text', () => {
      const pattern = new MentionPattern('@j')

      const result = pattern.findInText('@j question?', 0)

      expect(result).toEqual({
        from: 0,
        to: 12,
        text: '@j question?'
      })
    })

    test('finds mention in middle of text', () => {
      const pattern = new MentionPattern('@j')

      const result = pattern.findInText('hello @j question? world', 6)

      expect(result).toEqual({
        from: 6,
        to: 18,
        text: '@j question?'
      })
    })

    test('returns null when cursor not in mention', () => {
      const pattern = new MentionPattern('@j')

      const result = pattern.findInText('hello world', 5)

      expect(result).toBeNull()
    })

    test('returns null when cursor before mention', () => {
      const pattern = new MentionPattern('@j')

      const result = pattern.findInText('hello @j question?', 2)

      expect(result).toBeNull()
    })
  })

  describe('equals', () => {
    test('returns true for same pattern value', () => {
      const pattern1 = new MentionPattern('@j')
      const pattern2 = new MentionPattern('@j')

      expect(pattern1.equals(pattern2)).toBe(true)
    })

    test('returns false for different pattern values', () => {
      const pattern1 = new MentionPattern('@j')
      const pattern2 = new MentionPattern('@agent')

      expect(pattern1.equals(pattern2)).toBe(false)
    })
  })
})
