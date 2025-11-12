/**
 * ProseMirrorViewAdapter Tests
 *
 * Tests for the ProseMirror EditorView adapter that implements EditorAdapter interface.
 * Uses mocked EditorView since real ProseMirror setup is complex.
 *
 * @module __tests__/infrastructure/prosemirror
 */

import { describe, test, expect, vi, beforeEach } from 'vitest'
import { ProseMirrorViewAdapter } from '../../../infrastructure/prosemirror/prosemirror-view-adapter'
import type { EditorView } from '@milkdown/prose/view'

describe('ProseMirrorViewAdapter', () => {
  let mockView: EditorView
  let adapter: ProseMirrorViewAdapter

  beforeEach(() => {
    // Mock ProseMirror EditorView
    mockView = {
      state: {
        tr: {
          insert: vi.fn().mockReturnThis(),
          delete: vi.fn().mockReturnThis()
        },
        selection: {
          from: 5,
          to: 10
        },
        doc: {
          textBetween: vi.fn((_from: number, _to: number) => 'mock text')
        }
      },
      dispatch: vi.fn()
    } as any

    adapter = new ProseMirrorViewAdapter(mockView)
  })

  describe('constructor', () => {
    test('creates adapter with EditorView', () => {
      expect(adapter).toBeDefined()
    })

    test('throws error when EditorView is null', () => {
      expect(() => new ProseMirrorViewAdapter(null as any)).toThrow('EditorView is required')
    })
  })

  describe('insertNode', () => {
    test('inserts node at specified position', () => {
      const mockNode = { type: 'test-node' }
      const position = 10

      adapter.insertNode(mockNode, position)

      expect(mockView.state.tr.insert).toHaveBeenCalledWith(position, mockNode)
      expect(mockView.dispatch).toHaveBeenCalled()
    })

    test('throws error when position is negative', () => {
      const mockNode = { type: 'test-node' }

      expect(() => adapter.insertNode(mockNode, -1)).toThrow('Position must be non-negative')
    })

    test('handles node insertion at position 0', () => {
      const mockNode = { type: 'test-node' }

      adapter.insertNode(mockNode, 0)

      expect(mockView.state.tr.insert).toHaveBeenCalledWith(0, mockNode)
    })
  })

  describe('deleteRange', () => {
    test('deletes content between from and to positions', () => {
      adapter.deleteRange(5, 10)

      expect(mockView.state.tr.delete).toHaveBeenCalledWith(5, 10)
      expect(mockView.dispatch).toHaveBeenCalled()
    })

    test('throws error when from is negative', () => {
      expect(() => adapter.deleteRange(-1, 10)).toThrow('Positions must be non-negative')
    })

    test('throws error when to is negative', () => {
      expect(() => adapter.deleteRange(5, -1)).toThrow('Positions must be non-negative')
    })

    test('throws error when from is greater than to', () => {
      expect(() => adapter.deleteRange(10, 5)).toThrow('From position must be less than or equal to to position')
    })

    test('handles deletion when from equals to (empty range)', () => {
      adapter.deleteRange(5, 5)

      expect(mockView.state.tr.delete).toHaveBeenCalledWith(5, 5)
    })
  })

  describe('getSelection', () => {
    test('returns current selection from editor state', () => {
      const selection = adapter.getSelection()

      expect(selection).toEqual({ from: 5, to: 10 })
    })

    test('handles collapsed selection (cursor)', () => {
      mockView.state.selection = { from: 7, to: 7 } as any

      const selection = adapter.getSelection()

      expect(selection).toEqual({ from: 7, to: 7 })
    })
  })

  describe('getText', () => {
    test('extracts text between from and to positions', () => {
      const text = adapter.getText(5, 10)

      expect(mockView.state.doc.textBetween).toHaveBeenCalledWith(5, 10)
      expect(text).toBe('mock text')
    })

    test('throws error when from is negative', () => {
      expect(() => adapter.getText(-1, 10)).toThrow('Positions must be non-negative')
    })

    test('throws error when to is negative', () => {
      expect(() => adapter.getText(5, -1)).toThrow('Positions must be non-negative')
    })

    test('throws error when from is greater than to', () => {
      expect(() => adapter.getText(10, 5)).toThrow('From position must be less than or equal to to position')
    })

    test('handles empty range (from equals to)', () => {
      adapter.getText(5, 5)

      expect(mockView.state.doc.textBetween).toHaveBeenCalledWith(5, 5)
    })
  })

  describe('destroy', () => {
    test('removes reference to EditorView', () => {
      adapter.destroy()

      // After destroy, operations should throw
      expect(() => adapter.getSelection()).toThrow('Adapter has been destroyed')
    })

    test('prevents operations after destruction', () => {
      adapter.destroy()

      expect(() => adapter.insertNode({}, 0)).toThrow('Adapter has been destroyed')
      expect(() => adapter.deleteRange(0, 5)).toThrow('Adapter has been destroyed')
      expect(() => adapter.getText(0, 5)).toThrow('Adapter has been destroyed')
    })
  })
})
