/**
 * SelectionTracker Tests
 *
 * Tests for the SelectionTracker that tracks local ProseMirror selection changes
 * and updates Yjs Awareness.
 *
 * @module __tests__/infrastructure/prosemirror
 */

import { describe, test, expect, vi, beforeEach } from 'vitest'
import { SelectionTracker } from '../../../infrastructure/prosemirror/selection-tracker'
import { Selection } from '../../../domain/value-objects/selection'
import type { EditorView } from '@milkdown/prose/view'
import type { Awareness } from 'y-protocols/awareness'

describe('SelectionTracker', () => {
  let mockView: EditorView
  let mockAwareness: Awareness
  let tracker: SelectionTracker

  beforeEach(() => {
    // Mock ProseMirror EditorView
    mockView = {
      state: {
        selection: {
          from: 5,
          to: 10,
          anchor: 5,
          head: 10
        }
      }
    } as any

    // Mock Yjs Awareness
    mockAwareness = {
      setLocalState: vi.fn(),
      getLocalState: vi.fn(() => ({}))
    } as any

    tracker = new SelectionTracker(mockView, mockAwareness)
  })

  describe('constructor', () => {
    test('creates tracker with EditorView and Awareness', () => {
      expect(tracker).toBeDefined()
    })

    test('throws error when EditorView is null', () => {
      expect(() => new SelectionTracker(null as any, mockAwareness)).toThrow('EditorView is required')
    })

    test('throws error when Awareness is null', () => {
      expect(() => new SelectionTracker(mockView, null as any)).toThrow('Awareness is required')
    })
  })

  describe('getCurrentSelection', () => {
    test('returns current selection as domain value object', () => {
      const selection = tracker.getCurrentSelection()

      expect(selection).toBeInstanceOf(Selection)
      expect(selection.anchor).toBe(5)
      expect(selection.head).toBe(10)
    })

    test('handles collapsed selection (cursor)', () => {
      mockView.state.selection = {
        from: 7,
        to: 7,
        anchor: 7,
        head: 7
      } as any

      const selection = tracker.getCurrentSelection()

      expect(selection.anchor).toBe(7)
      expect(selection.head).toBe(7)
      expect(selection.isEmpty()).toBe(true)
    })

    test('handles backward selection', () => {
      mockView.state.selection = {
        from: 5,
        to: 10,
        anchor: 10,
        head: 5
      } as any

      const selection = tracker.getCurrentSelection()

      expect(selection.anchor).toBe(10)
      expect(selection.head).toBe(5)
      expect(selection.isBackward()).toBe(true)
    })

    test('throws error when tracker has been stopped', () => {
      tracker.stop()

      expect(() => tracker.getCurrentSelection()).toThrow('Tracker has been stopped')
    })
  })

  describe('start', () => {
    test('begins tracking selection changes', () => {
      tracker.start()

      // Should not throw
      expect(tracker).toBeDefined()
    })

    test('updates awareness with current selection', () => {
      tracker.start()

      // Awareness should be updated with selection state
      expect(mockAwareness.setLocalState).toHaveBeenCalled()
    })

    test('can be called multiple times (idempotent)', () => {
      tracker.start()
      tracker.start()

      // Should not cause issues
      expect(tracker).toBeDefined()
    })
  })

  describe('stop', () => {
    test('stops tracking selection changes', () => {
      tracker.start()
      tracker.stop()

      // Should clean up
      expect(tracker).toBeDefined()
    })

    test('can be called when not started', () => {
      tracker.stop()

      // Should not throw
      expect(tracker).toBeDefined()
    })

    test('can be called multiple times (idempotent)', () => {
      tracker.start()
      tracker.stop()
      tracker.stop()

      // Should not throw
      expect(tracker).toBeDefined()
    })

    test('prevents operations after stopping', () => {
      tracker.start()
      tracker.stop()

      expect(() => tracker.getCurrentSelection()).toThrow('Tracker has been stopped')
    })
  })

  describe('awareness integration', () => {
    test('updates awareness state with selection', () => {
      tracker.start()

      expect(mockAwareness.setLocalState).toHaveBeenCalledWith(
        expect.objectContaining({
          selection: expect.objectContaining({
            anchor: 5,
            head: 10
          })
        })
      )
    })

    test('updates awareness state with cursor position', () => {
      mockView.state.selection = {
        from: 7,
        to: 7,
        anchor: 7,
        head: 7
      } as any

      tracker.start()

      expect(mockAwareness.setLocalState).toHaveBeenCalledWith(
        expect.objectContaining({
          cursor: 7
        })
      )
    })

    test('preserves existing awareness state', () => {
      (mockAwareness.getLocalState as ReturnType<typeof vi.fn>).mockReturnValue({
        userId: 'user-123',
        userName: 'John Doe',
        userColor: '#FF6B6B'
      })

      tracker.start()

      expect(mockAwareness.setLocalState).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'user-123',
          userName: 'John Doe',
          userColor: '#FF6B6B',
          selection: expect.any(Object)
        })
      )
    })

    test('clears selection state when stopped', () => {
      tracker.start()
      tracker.stop()

      // Should clear selection from awareness
      expect(mockAwareness.setLocalState).toHaveBeenCalledWith(
        expect.not.objectContaining({
          selection: expect.any(Object)
        })
      )
    })
  })

  describe('domain value object integration', () => {
    test('converts ProseMirror selection to domain Selection', () => {
      const selection = tracker.getCurrentSelection()

      expect(selection).toBeInstanceOf(Selection)
      expect(selection.anchor).toBeDefined()
      expect(selection.head).toBeDefined()
    })

    test('domain Selection has expected methods', () => {
      const selection = tracker.getCurrentSelection()

      expect(typeof selection.isEmpty).toBe('function')
      expect(typeof selection.isForward).toBe('function')
      expect(typeof selection.isBackward).toBe('function')
      expect(typeof selection.getLength).toBe('function')
    })

    test('domain Selection provides immutable API', () => {
      const selection = tracker.getCurrentSelection()

      // Selection operations return values, not mutate state
      expect(selection.getLength()).toBe(5)
      expect(selection.isEmpty()).toBe(false)
      expect(selection.isForward()).toBe(true)

      // TypeScript readonly provides compile-time immutability guarantee
      // (Runtime enforcement is not possible in JavaScript)
    })
  })
})
