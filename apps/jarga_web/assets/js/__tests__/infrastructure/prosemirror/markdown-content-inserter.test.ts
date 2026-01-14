import { describe, test, expect, vi, beforeEach } from 'vitest'
import { MarkdownContentInserter } from '../../../infrastructure/prosemirror/markdown-content-inserter'
import type { IMarkdownParserAdapter } from '../../../application/interfaces/markdown-parser-adapter'
import type { EditorView } from '@milkdown/prose/view'
import type { Node as ProseMirrorNode } from '@milkdown/prose/model'
import { Selection } from '@milkdown/prose/state'

describe('MarkdownContentInserter', () => {
  let mockView: Partial<EditorView>
  let mockParser: IMarkdownParserAdapter
  let inserter: MarkdownContentInserter
  let mockDispatch: ReturnType<typeof vi.fn>
  let mockFocus: ReturnType<typeof vi.fn>

  beforeEach(() => {
    mockDispatch = vi.fn()
    mockFocus = vi.fn()

    // Mock Selection.near as a static method
    vi.spyOn(Selection, 'near').mockReturnValue({} as any)

    // Create a minimal mock transaction
    const mockTr = {
      delete: vi.fn().mockReturnThis(),
      insert: vi.fn().mockReturnThis(),
      setSelection: vi.fn().mockReturnThis(),
      doc: {
        resolve: vi.fn().mockReturnValue({ pos: 10 })
      }
    }

    // Create a minimal mock selection
    const mockSelection = {
      from: 5,
      to: 5,
      empty: true
    }

    mockView = {
      state: {
        selection: mockSelection,
        tr: mockTr
      } as any,
      dispatch: mockDispatch,
      focus: mockFocus
    } as any

    mockParser = {
      parse: vi.fn(),
      parseInline: vi.fn()
    }

    inserter = new MarkdownContentInserter(
      mockView as EditorView,
      mockParser
    )
  })

  describe('insertMarkdown', () => {
    test('parses markdown and inserts nodes at cursor', () => {
      const markdown = '# Heading'
      const mockNode = { nodeSize: 10 } as ProseMirrorNode

      // Mock parse to return doc with content array that has forEach
      const mockContent = [mockNode]
      vi.mocked(mockParser.parse).mockReturnValue({
        content: {
          length: mockContent.length,
          forEach: (fn: (node: ProseMirrorNode) => void) => mockContent.forEach(fn)
        }
      } as any)

      inserter.insertMarkdown(markdown)

      expect(mockParser.parse).toHaveBeenCalledWith(markdown)
      expect(mockView.state!.tr.insert).toHaveBeenCalledWith(5, mockNode)
      expect(mockDispatch).toHaveBeenCalled()
      expect(mockFocus).toHaveBeenCalled()
    })

    test('inserts multiple nodes sequentially', () => {
      const markdown = '# Heading\n\nParagraph'
      const mockNode1 = { nodeSize: 10 } as ProseMirrorNode
      const mockNode2 = { nodeSize: 15 } as ProseMirrorNode

      const mockContent = [mockNode1, mockNode2]
      vi.mocked(mockParser.parse).mockReturnValue({
        content: {
          length: mockContent.length,
          forEach: (fn: (node: ProseMirrorNode) => void) => mockContent.forEach(fn)
        }
      } as any)

      inserter.insertMarkdown(markdown)

      // First node inserted at cursor position (5)
      expect(mockView.state!.tr.insert).toHaveBeenCalledWith(5, mockNode1)
      // Second node inserted after first node (5 + 10 = 15)
      expect(mockView.state!.tr.insert).toHaveBeenCalledWith(15, mockNode2)
    })

    test('deletes selection before inserting when selection is not empty', () => {
      const markdown = '# Heading'
      const mockNode = { nodeSize: 10 } as ProseMirrorNode

      // Create a new mock selection with non-empty range
      const mockNonEmptySelection = {
        from: 5,
        to: 10,
        empty: false
      }

      // Update the view state with the new selection
      mockView.state = {
        selection: mockNonEmptySelection,
        tr: mockView.state!.tr
      } as any

      const mockContent = [mockNode]
      vi.mocked(mockParser.parse).mockReturnValue({
        content: {
          length: mockContent.length,
          forEach: (fn: (node: ProseMirrorNode) => void) => mockContent.forEach(fn)
        }
      } as any)

      inserter.insertMarkdown(markdown)

      expect(mockView.state!.tr.delete).toHaveBeenCalledWith(5, 10)
      expect(mockView.state!.tr.insert).toHaveBeenCalledWith(5, mockNode)
    })

    test('does nothing when parser returns empty content', () => {
      const markdown = 'invalid'
      vi.mocked(mockParser.parse).mockReturnValue({
        content: { length: 0, forEach: () => {} }
      } as any)

      const consoleSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})

      inserter.insertMarkdown(markdown)

      expect(mockDispatch).not.toHaveBeenCalled()
      expect(consoleSpy).toHaveBeenCalledWith(
        '[MarkdownContentInserter] Failed to parse markdown'
      )

      consoleSpy.mockRestore()
    })


    test('moves cursor to end of inserted content', () => {
      const markdown = '# Heading'
      const mockNode = { nodeSize: 10 } as ProseMirrorNode

      const mockContent = [mockNode]
      vi.mocked(mockParser.parse).mockReturnValue({
        content: {
          length: mockContent.length,
          forEach: (fn: (node: ProseMirrorNode) => void) => mockContent.forEach(fn)
        }
      } as any)

      inserter.insertMarkdown(markdown)

      // Should resolve position after insertion (5 + 10 = 15)
      expect(mockView.state!.tr.doc.resolve).toHaveBeenCalled()
      expect(Selection.near).toHaveBeenCalled()
    })

    test('uses parse instead of parseInline for full document insertion', () => {
      // This test ensures we use parse() to get ALL blocks, not just the first one
      const multilineMarkdown = '# Heading\n\nParagraph 1\n\n- Item 1\n- Item 2'

      // Mock parse to return a doc with content that has forEach
      const mockNodes = [
        { nodeSize: 10 },
        { nodeSize: 15 },
        { nodeSize: 20 }
      ]
      vi.mocked(mockParser.parse).mockReturnValue({
        content: {
          length: mockNodes.length,
          forEach: (fn: (node: ProseMirrorNode) => void) => mockNodes.forEach(fn as any)
        }
      } as any)

      inserter.insertMarkdown(multilineMarkdown)

      // Should call parse, not parseInline
      expect(mockParser.parse).toHaveBeenCalledWith(multilineMarkdown)
      // parseInline should NOT be called - we need full document parsing
      expect(mockParser.parseInline).not.toHaveBeenCalled()
    })
  })
})
