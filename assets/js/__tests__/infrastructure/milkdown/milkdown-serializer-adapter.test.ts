import { describe, test, expect, beforeEach, vi } from 'vitest'
import { MilkdownSerializerAdapter } from '../../../infrastructure/milkdown/milkdown-serializer-adapter'
import type { Ctx } from '@milkdown/ctx'
import type { Node } from 'prosemirror-model'

describe('MilkdownSerializerAdapter', () => {
  let adapter: MilkdownSerializerAdapter
  let mockCtx: Ctx
  let mockSerializer: (node: Node) => string

  beforeEach(() => {
    // Create mock serializer function
    mockSerializer = vi.fn((node: Node) => {
      // Simple mock: convert node to markdown-like string
      return `markdown: ${node.type?.name || 'unknown'}`
    })

    // Create mock Milkdown context
    mockCtx = {
      get: vi.fn((_key: any) => {
        // Return mock serializer when serializerCtx is requested
        return mockSerializer
      })
    } as any

    adapter = new MilkdownSerializerAdapter(mockCtx)
  })

  describe('constructor', () => {
    test('creates adapter with Milkdown context', () => {
      const adapter = new MilkdownSerializerAdapter(mockCtx)

      expect(adapter).toBeDefined()
    })

    test('stores reference to context', () => {
      const customCtx = { get: vi.fn() } as any
      const adapter = new MilkdownSerializerAdapter(customCtx)

      expect(adapter).toBeDefined()
    })
  })

  describe('serialize', () => {
    test('converts ProseMirror document to markdown', () => {
      const mockDoc = {
        type: { name: 'doc' },
        nodeSize: 5
      } as any

      const markdown = adapter.serialize(mockDoc)

      expect(typeof markdown).toBe('string')
      expect(markdown.length).toBeGreaterThan(0)
    })

    test('handles empty document', () => {
      const emptyDoc = {
        type: { name: 'doc' },
        nodeSize: 2
      } as any

      const markdown = adapter.serialize(emptyDoc)

      expect(typeof markdown).toBe('string')
    })

    test('calls Milkdown serializer with document', () => {
      const mockDoc = {
        type: { name: 'doc' },
        nodeSize: 10
      } as any

      adapter.serialize(mockDoc)

      expect(mockSerializer).toHaveBeenCalledWith(mockDoc)
    })

    test('returns empty string when serializer returns empty', () => {
      mockSerializer = vi.fn(() => '')
      mockCtx = {
        get: vi.fn(() => mockSerializer)
      } as any
      adapter = new MilkdownSerializerAdapter(mockCtx)

      const mockDoc = { type: { name: 'doc' } } as any

      const markdown = adapter.serialize(mockDoc)

      expect(markdown).toBe('')
    })

    test('handles complex document structure', () => {
      const complexDoc = {
        type: { name: 'doc' },
        content: [
          { type: { name: 'paragraph' } },
          { type: { name: 'heading' } }
        ]
      } as any

      const markdown = adapter.serialize(complexDoc)

      expect(typeof markdown).toBe('string')
    })
  })

  describe('serializeSelection', () => {
    test('serializes current selection to markdown', () => {
      const mockState = {
        doc: { type: { name: 'doc' } },
        selection: {
          from: 0,
          to: 10,
          content: vi.fn().mockReturnValue({
            content: []
          })
        }
      } as any

      const markdown = adapter.serializeSelection(mockState)

      expect(typeof markdown).toBe('string')
    })

    test('handles empty selection', () => {
      const mockState = {
        doc: { type: { name: 'doc' } },
        selection: {
          from: 5,
          to: 5,
          empty: true,
          content: vi.fn().mockReturnValue({
            content: []
          })
        }
      } as any

      const markdown = adapter.serializeSelection(mockState)

      expect(typeof markdown).toBe('string')
      expect(markdown).toBe('')
    })

    test('extracts and serializes selection content', () => {
      const mockState = {
        doc: {
          type: { name: 'doc' },
          cut: vi.fn().mockReturnValue({
            content: [{ type: { name: 'paragraph' } }]
          })
        },
        selection: {
          from: 1,
          to: 10
        }
      } as any

      const markdown = adapter.serializeSelection(mockState)

      expect(mockState.doc.cut).toHaveBeenCalledWith(1, 10)
      expect(typeof markdown).toBe('string')
    })

    test('handles selection spanning multiple nodes', () => {
      const mockState = {
        doc: {
          type: { name: 'doc' },
          cut: vi.fn().mockReturnValue({
            content: [
              { type: { name: 'paragraph' } },
              { type: { name: 'paragraph' } }
            ]
          })
        },
        selection: {
          from: 0,
          to: 20
        }
      } as any

      const markdown = adapter.serializeSelection(mockState)

      expect(typeof markdown).toBe('string')
    })

    test('returns empty string for collapsed cursor', () => {
      const mockState = {
        doc: { type: { name: 'doc' } },
        selection: {
          from: 5,
          to: 5,
          empty: true
        }
      } as any

      const markdown = adapter.serializeSelection(mockState)

      expect(markdown).toBe('')
    })
  })

  describe('error handling', () => {
    test('handles serializer errors gracefully', () => {
      mockSerializer = vi.fn(() => {
        throw new Error('Serializer error')
      })
      mockCtx = {
        get: vi.fn(() => mockSerializer)
      } as any
      adapter = new MilkdownSerializerAdapter(mockCtx)

      const mockDoc = { type: { name: 'doc' } } as any

      expect(() => adapter.serialize(mockDoc)).not.toThrow()
    })

    test('returns empty string on serialization error', () => {
      mockSerializer = vi.fn(() => {
        throw new Error('Serializer error')
      })
      mockCtx = {
        get: vi.fn(() => mockSerializer)
      } as any
      adapter = new MilkdownSerializerAdapter(mockCtx)

      const mockDoc = { type: { name: 'doc' } } as any

      const markdown = adapter.serialize(mockDoc)

      expect(markdown).toBe('')
    })
  })
})
