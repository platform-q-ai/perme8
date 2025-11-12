/**
 * MarkdownParserAdapter Tests
 */

import { describe, test, expect, beforeEach, vi } from 'vitest'
import { MarkdownParserAdapter } from '../../../infrastructure/milkdown/markdown-parser-adapter'
import { Schema } from '@milkdown/prose/model'

describe('MarkdownParserAdapter', () => {
  let adapter: MarkdownParserAdapter
  let mockParser: any
  let schema: Schema

  beforeEach(() => {
    // Create a minimal schema for testing
    schema = new Schema({
      nodes: {
        doc: { content: 'block+' },
        paragraph: { content: 'text*', group: 'block' },
        text: { group: 'inline' }
      }
    })

    mockParser = vi.fn()
    adapter = new MarkdownParserAdapter(mockParser)
  })

  describe('parse', () => {
    test('trims markdown and calls parser', () => {
      const markdown = '  # Hello\n\nWorld  '
      const mockNode = schema.node('doc', null, [
        schema.node('paragraph', null, [schema.text('Hello')])
      ])
      mockParser.mockReturnValue(mockNode)

      const result = adapter.parse(markdown)

      expect(mockParser).toHaveBeenCalledWith(markdown.trim())
      expect(result).not.toBeNull()
      expect(result?.content).toHaveLength(1)
    })

    test('returns null for empty markdown', () => {
      const result = adapter.parse('   ')

      expect(mockParser).not.toHaveBeenCalled()
      expect(result).toBeNull()
    })

    test('returns null when parser returns string (error)', () => {
      mockParser.mockReturnValue('Parse error')

      const result = adapter.parse('invalid')

      expect(result).toBeNull()
    })

    test('returns null when parser returns null', () => {
      mockParser.mockReturnValue(null)

      const result = adapter.parse('test')

      expect(result).toBeNull()
    })

    test('returns null when parser throws error', () => {
      mockParser.mockImplementation(() => {
        throw new Error('Parse error')
      })

      const result = adapter.parse('invalid')

      expect(result).toBeNull()
    })

    test('extracts content nodes from parsed document', () => {
      const mockNode = schema.node('doc', null, [
        schema.node('paragraph', null, [schema.text('Hello')]),
        schema.node('paragraph', null, [schema.text('World')])
      ])
      mockParser.mockReturnValue(mockNode)

      const result = adapter.parse('# Hello\n\nWorld')

      expect(result).not.toBeNull()
      expect(result?.content).toHaveLength(2)
      expect(result?.content[0].type.name).toBe('paragraph')
      expect(result?.content[1].type.name).toBe('paragraph')
    })

    test('handles empty markdown string', () => {
      // Empty markdown is handled before parsing
      const result = adapter.parse('')

      // Empty markdown returns null before calling parser
      expect(result).toBeNull()
      expect(mockParser).not.toHaveBeenCalled()
    })

    test('iterates through content correctly', () => {
      const para1 = schema.node('paragraph', null, [schema.text('First')])
      const para2 = schema.node('paragraph', null, [schema.text('Second')])
      const mockNode = schema.node('doc', null, [para1, para2])
      mockParser.mockReturnValue(mockNode)

      const result = adapter.parse('First\n\nSecond')

      expect(result).not.toBeNull()
      expect(result?.content).toHaveLength(2)
      expect(result?.content[0]).toBe(para1)
      expect(result?.content[1]).toBe(para2)
    })
  })
})
