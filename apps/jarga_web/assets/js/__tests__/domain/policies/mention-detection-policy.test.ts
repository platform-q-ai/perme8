import { describe, test, expect } from 'vitest'
import { MentionDetectionPolicy } from '../../../domain/policies/mention-detection-policy'
import { MentionPattern } from '../../../domain/value-objects/mention-pattern'

describe('MentionDetectionPolicy', () => {
  describe('constructor', () => {
    test('creates policy with mention pattern', () => {
      const pattern = new MentionPattern('@j')

      const policy = new MentionDetectionPolicy(pattern)

      expect(policy.pattern).toEqual(pattern)
    })
  })

  describe('detectAtCursor', () => {
    test('detects mention when cursor is within @j mention', () => {
      const pattern = new MentionPattern('@j')
      const policy = new MentionDetectionPolicy(pattern)

      const result = policy.detectAtCursor('@j what is TypeScript?', 5)

      expect(result).not.toBeNull()
      expect(result?.from).toBe(0)
      expect(result?.to).toBe(22)
      expect(result?.text).toBe('@j what is TypeScript?')
    })

    test('returns null when cursor is not in mention', () => {
      const pattern = new MentionPattern('@j')
      const policy = new MentionDetectionPolicy(pattern)

      const result = policy.detectAtCursor('hello world', 5)

      expect(result).toBeNull()
    })

    test('returns null when cursor is before mention', () => {
      const pattern = new MentionPattern('@j')
      const policy = new MentionDetectionPolicy(pattern)

      const result = policy.detectAtCursor('hello @j question?', 2)

      expect(result).toBeNull()
    })

    test('returns null when cursor is after mention', () => {
      const pattern = new MentionPattern('@j')
      const policy = new MentionDetectionPolicy(pattern)

      const result = policy.detectAtCursor('@j question? hello', 16)

      expect(result).toBeNull()
    })

    test('detects mention at start of text', () => {
      const pattern = new MentionPattern('@j')
      const policy = new MentionDetectionPolicy(pattern)

      const result = policy.detectAtCursor('@j question?', 0)

      expect(result).not.toBeNull()
      expect(result?.from).toBe(0)
    })

    test('detects mention in middle of text', () => {
      const pattern = new MentionPattern('@j')
      const policy = new MentionDetectionPolicy(pattern)

      const result = policy.detectAtCursor('hello @j question? world', 8)

      expect(result).not.toBeNull()
      expect(result?.from).toBe(6)
      expect(result?.to).toBe(18)
    })
  })

  describe('extractQuestion', () => {
    test('extracts question from detected mention', () => {
      const pattern = new MentionPattern('@j')
      const policy = new MentionDetectionPolicy(pattern)
      const detection = policy.detectAtCursor('@j what is TypeScript?', 5)

      const question = policy.extractQuestion(detection!)

      expect(question).toBe('what is TypeScript?')
    })

    test('returns null when no mention text', () => {
      const pattern = new MentionPattern('@j')
      const policy = new MentionDetectionPolicy(pattern)

      const question = policy.extractQuestion(null)

      expect(question).toBeNull()
    })

    test('returns null for empty question', () => {
      const pattern = new MentionPattern('@j')
      const policy = new MentionDetectionPolicy(pattern)
      const detection = { from: 0, to: 3, text: '@j ' }

      const question = policy.extractQuestion(detection)

      expect(question).toBeNull()
    })

    test('trims whitespace from question', () => {
      const pattern = new MentionPattern('@j')
      const policy = new MentionDetectionPolicy(pattern)
      const detection = { from: 0, to: 10, text: '@j   test   ' }

      const question = policy.extractQuestion(detection)

      expect(question).toBe('test')
    })
  })

  describe('isValidForQuery', () => {
    test('returns true for valid mention with question', () => {
      const pattern = new MentionPattern('@j')
      const policy = new MentionDetectionPolicy(pattern)
      const detection = { from: 0, to: 22, text: '@j what is TypeScript?' }

      const valid = policy.isValidForQuery(detection)

      expect(valid).toBe(true)
    })

    test('returns false for null detection', () => {
      const pattern = new MentionPattern('@j')
      const policy = new MentionDetectionPolicy(pattern)

      const valid = policy.isValidForQuery(null)

      expect(valid).toBe(false)
    })

    test('returns false for mention without question', () => {
      const pattern = new MentionPattern('@j')
      const policy = new MentionDetectionPolicy(pattern)
      const detection = { from: 0, to: 3, text: '@j ' }

      const valid = policy.isValidForQuery(detection)

      expect(valid).toBe(false)
    })

    test('returns false for whitespace-only question', () => {
      const pattern = new MentionPattern('@j')
      const policy = new MentionDetectionPolicy(pattern)
      const detection = { from: 0, to: 10, text: '@j        ' }

      const valid = policy.isValidForQuery(detection)

      expect(valid).toBe(false)
    })
  })
})
