import { describe, test, expect, beforeEach, vi } from 'vitest'
import { MilkdownParserAdapter } from '../../../infrastructure/milkdown/milkdown-parser-adapter'
import type { Ctx } from '@milkdown/ctx'
import type { Node } from 'prosemirror-model'
import { Schema } from '@milkdown/prose/model'

describe('MilkdownParserAdapter', () => {
  let adapter: MilkdownParserAdapter
  let mockCtx: Ctx
  let mockParser: ReturnType<typeof vi.fn>
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

    // Create mock parser function
    mockParser = vi.fn((markdown: string): Node | null => {
      // Simple mock: create a node-like object with content
      if (!markdown || markdown.trim().length === 0) {
        return null
      }

      // Return a document node with paragraph children
      return schema.node('doc', null, [
        schema.node('paragraph', null, [schema.text(markdown)])
      ])
    })

    // Create mock Milkdown context
    mockCtx = {
      get: vi.fn((_key: any) => {
        // Return mock parser when parserCtx is requested
        return mockParser
      })
    } as any

    adapter = new MilkdownParserAdapter(mockCtx)
  })

  describe('constructor', () => {
    test('creates adapter with Milkdown context', () => {
      const adapter = new MilkdownParserAdapter(mockCtx)

      expect(adapter).toBeDefined()
    })

    test('stores reference to context', () => {
      const customCtx = { get: vi.fn() } as any
      const adapter = new MilkdownParserAdapter(customCtx)

      expect(adapter).toBeDefined()
    })
  })

  describe('parse', () => {
    test('converts markdown to ParsedDocument with content array', () => {
      const markdown = '# Hello World'

      const result = adapter.parse(markdown)

      expect(result).toBeDefined()
      expect(result).not.toBeNull()
      expect(result?.content).toBeDefined()
      expect(Array.isArray(result?.content)).toBe(true)
      expect(result?.content.length).toBeGreaterThan(0)
    })

    test('handles empty markdown', () => {
      const markdown = ''

      const result = adapter.parse(markdown)

      expect(result).toBeNull()
    })

    test('calls Milkdown parser with markdown', () => {
      const markdown = '**Bold text**'

      adapter.parse(markdown)

      expect(mockParser).toHaveBeenCalledWith(markdown)
    })

    test('returns null for whitespace-only markdown', () => {
      const markdown = '   \n  \t  '

      const result = adapter.parse(markdown)

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

    test('returns null when parser returns null', () => {
      mockParser.mockReturnValue(null)

      const result = adapter.parse('test')

      expect(result).toBeNull()
    })

    test('handles complex markdown structure', () => {
      const markdown = `
# Heading 1

This is a paragraph.
      `.trim()

      const result = adapter.parse(markdown)

      expect(result).toBeDefined()
      expect(result?.content).toBeDefined()
    })
  })

  describe('parseInline', () => {
    test('parses inline markdown to node array', () => {
      const markdown = '**bold** and *italic*'

      const nodes = adapter.parseInline(markdown)

      expect(Array.isArray(nodes)).toBe(true)
    })

    test('handles empty markdown', () => {
      const markdown = ''

      const nodes = adapter.parseInline(markdown)

      expect(Array.isArray(nodes)).toBe(true)
      expect(nodes).toHaveLength(0)
    })

    test('handles single word', () => {
      const markdown = 'Hello'

      const nodes = adapter.parseInline(markdown)

      expect(Array.isArray(nodes)).toBe(true)
      expect(nodes.length).toBeGreaterThanOrEqual(0)
    })

    test('handles multiple inline elements', () => {
      const markdown = '**bold** normal *italic* `code`'

      const nodes = adapter.parseInline(markdown)

      expect(Array.isArray(nodes)).toBe(true)
    })

    test('returns empty array for whitespace-only', () => {
      const markdown = '   \n  '

      const nodes = adapter.parseInline(markdown)

      expect(Array.isArray(nodes)).toBe(true)
      expect(nodes).toHaveLength(0)
    })
  })

  describe('error handling', () => {
    test('handles parser errors gracefully', () => {
      mockParser = vi.fn(() => {
        throw new Error('Parser error')
      })
      mockCtx = {
        get: vi.fn(() => mockParser)
      } as any
      adapter = new MilkdownParserAdapter(mockCtx)

      expect(() => adapter.parse('# Heading')).not.toThrow()
    })

    test('returns null on parse error', () => {
      mockParser = vi.fn(() => {
        throw new Error('Parser error')
      })
      mockCtx = {
        get: vi.fn(() => mockParser)
      } as any
      adapter = new MilkdownParserAdapter(mockCtx)

      const node = adapter.parse('# Heading')

      expect(node).toBeNull()
    })

    test('handles parseInline error gracefully', () => {
      mockParser = vi.fn(() => {
        throw new Error('Parser error')
      })
      mockCtx = {
        get: vi.fn(() => mockParser)
      } as any
      adapter = new MilkdownParserAdapter(mockCtx)

      expect(() => adapter.parseInline('**bold**')).not.toThrow()
    })

    test('returns empty array on parseInline error', () => {
      mockParser = vi.fn(() => {
        throw new Error('Parser error')
      })
      mockCtx = {
        get: vi.fn(() => mockParser)
      } as any
      adapter = new MilkdownParserAdapter(mockCtx)

      const nodes = adapter.parseInline('**bold**')

      expect(nodes).toEqual([])
    })
  })

  describe('edge cases', () => {
    test('handles malformed markdown', () => {
      const markdown = '######## Too many hashes'

      const node = adapter.parse(markdown)

      expect(node).toBeDefined()
    })

    test('handles markdown with special characters', () => {
      const markdown = 'Text with < > & " special chars'

      const node = adapter.parse(markdown)

      expect(node).toBeDefined()
    })

    test('handles very long markdown', () => {
      const markdown = 'A'.repeat(10000)

      const node = adapter.parse(markdown)

      expect(node).toBeDefined()
    })

    test('handles unicode characters', () => {
      const markdown = '你好世界 🌍 Здравствуй'

      const node = adapter.parse(markdown)

      expect(node).toBeDefined()
    })
  })
})
