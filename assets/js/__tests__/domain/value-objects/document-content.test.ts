import { describe, test, expect } from 'vitest'
import { DocumentContent } from '../../../domain/value-objects/document-content'

describe('DocumentContent', () => {
  describe('constructor', () => {
    test('creates DocumentContent with markdown string', () => {
      const content = new DocumentContent('# Hello World')

      expect(content.value).toBe('# Hello World')
    })

    test('creates DocumentContent with empty string (new document)', () => {
      const content = new DocumentContent('')

      expect(content.value).toBe('')
    })

    test('creates DocumentContent with multi-line markdown', () => {
      const markdown = '# Title\n\nParagraph text\n\n- List item'
      const content = new DocumentContent(markdown)

      expect(content.value).toBe(markdown)
    })
  })

  describe('characterCount', () => {
    test('returns correct character count for simple text', () => {
      const content = new DocumentContent('Hello')

      expect(content.characterCount()).toBe(5)
    })

    test('returns zero for empty content', () => {
      const content = new DocumentContent('')

      expect(content.characterCount()).toBe(0)
    })

    test('includes newlines in character count', () => {
      const content = new DocumentContent('Line 1\nLine 2')

      expect(content.characterCount()).toBe(13) // 'Line 1' (6) + '\n' (1) + 'Line 2' (6)
    })

    test('includes markdown syntax in character count', () => {
      const content = new DocumentContent('# Heading')

      expect(content.characterCount()).toBe(9) // '# Heading' = 9 chars
    })
  })

  describe('lineCount', () => {
    test('returns 1 for single line', () => {
      const content = new DocumentContent('Single line')

      expect(content.lineCount()).toBe(1)
    })

    test('returns 0 for empty content', () => {
      const content = new DocumentContent('')

      expect(content.lineCount()).toBe(0)
    })

    test('returns correct count for multiple lines', () => {
      const content = new DocumentContent('Line 1\nLine 2\nLine 3')

      expect(content.lineCount()).toBe(3)
    })

    test('handles trailing newline correctly', () => {
      const content = new DocumentContent('Line 1\nLine 2\n')

      expect(content.lineCount()).toBe(2) // Two lines, trailing newline doesn't create a third
    })

    test('counts empty lines', () => {
      const content = new DocumentContent('Line 1\n\nLine 3')

      expect(content.lineCount()).toBe(3) // Includes the empty line
    })
  })

  describe('isEmpty', () => {
    test('returns true for empty string', () => {
      const content = new DocumentContent('')

      expect(content.isEmpty()).toBe(true)
    })

    test('returns false for non-empty content', () => {
      const content = new DocumentContent('Some text')

      expect(content.isEmpty()).toBe(false)
    })

    test('returns false for whitespace-only content', () => {
      const content = new DocumentContent('   ')

      expect(content.isEmpty()).toBe(false)
    })

    test('returns false for newline-only content', () => {
      const content = new DocumentContent('\n')

      expect(content.isEmpty()).toBe(false)
    })
  })

  describe('equals', () => {
    test('returns true for same content value', () => {
      const content1 = new DocumentContent('# Hello')
      const content2 = new DocumentContent('# Hello')

      expect(content1.equals(content2)).toBe(true)
    })

    test('returns false for different content values', () => {
      const content1 = new DocumentContent('# Hello')
      const content2 = new DocumentContent('# Goodbye')

      expect(content1.equals(content2)).toBe(false)
    })

    test('returns true when compared with itself', () => {
      const content = new DocumentContent('# Hello')

      expect(content.equals(content)).toBe(true)
    })

    test('returns true for two empty contents', () => {
      const content1 = new DocumentContent('')
      const content2 = new DocumentContent('')

      expect(content1.equals(content2)).toBe(true)
    })
  })

  describe('toString', () => {
    test('returns the content value', () => {
      const content = new DocumentContent('# Markdown')

      expect(content.toString()).toBe('# Markdown')
    })

    test('returns empty string for empty content', () => {
      const content = new DocumentContent('')

      expect(content.toString()).toBe('')
    })
  })

  describe('immutability', () => {
    test('creates a new instance with same value when accessed', () => {
      const content = new DocumentContent('# Title')

      // Value is immutable - TypeScript prevents modification at compile time
      expect(content.value).toBe('# Title')

      // Creating a new instance doesn't affect the original
      const content2 = new DocumentContent('# Other')
      expect(content.value).toBe('# Title')
      expect(content2.value).toBe('# Other')
    })
  })
})
