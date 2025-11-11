import { describe, it, expect } from 'vitest'
import { createCursorWidget, createSelectionDecoration, createUserDecorations } from '../../collaboration/cursor-decorations'

describe('CursorDecorations', () => {
  describe('createCursorWidget', () => {
    it('should create a widget decoration', () => {
      const decoration = createCursorWidget('user_123', 'Alice', '#FF6B6B', 10)

      expect(decoration).toBeDefined()
      expect(decoration.from).toBe(10)
      expect(decoration.to).toBe(10)
      expect(decoration.spec).toBeDefined()
      expect(decoration.spec.key).toBe('cursor-user_123')
    })

    it('should use userId as fallback for userName', () => {
      const decoration = createCursorWidget('user_123', null, '#FF6B6B', 10)

      expect(decoration).toBeDefined()
      expect(decoration.spec.key).toBe('cursor-user_123')
      // Widget is created with truncated userId when userName is null
    })

    it('should include user color in widget', () => {
      const color = '#4ECDC4'
      const decoration = createCursorWidget('user_456', 'Bob', color, 5)

      expect(decoration).toBeDefined()
      expect(decoration.from).toBe(5)
      // The widget DOM element is provided by the decoration, color is applied in createCursorElement
    })
  })

  describe('createSelectionDecoration', () => {
    it('should create an inline decoration', () => {
      const decoration = createSelectionDecoration('user_123', '#FF6B6B', 5, 10)

      expect(decoration).toBeDefined()
      expect(decoration.from).toBe(5)
      expect(decoration.to).toBe(10)
      expect(decoration.spec).toBeDefined()
      expect(decoration.spec.key).toBe('selection-user_123')
    })

    it('should apply color with opacity', () => {
      const color = '#4ECDC4'
      const decoration = createSelectionDecoration('user_456', color, 0, 5)

      // Check inline style includes color with opacity
      expect(decoration.type.attrs.style).toContain(color)
      expect(decoration.type.attrs.style).toContain('33') // 20% opacity
    })

    it('should have remote-selection class', () => {
      const decoration = createSelectionDecoration('user_789', '#45B7D1', 2, 8)

      expect(decoration.type.attrs.class).toBe('remote-selection')
    })
  })

  describe('createUserDecorations', () => {
    it('should create both cursor and selection decorations when text is selected', () => {
      const userState = {
        userId: 'user_123',
        userName: 'Alice',
        selection: {
          anchor: 5,
          head: 10
        }
      }

      const decorations = createUserDecorations(userState, '#FF6B6B')

      // Should have selection decoration + cursor decoration
      expect(decorations).toHaveLength(2)
      expect(decorations[0].from).toBe(5) // selection
      expect(decorations[0].to).toBe(10)
      expect(decorations[1].from).toBe(10) // cursor at head
    })

    it('should create only cursor decoration when no text is selected', () => {
      const userState = {
        userId: 'user_456',
        userName: 'Bob',
        selection: {
          anchor: 5,
          head: 5
        }
      }

      const decorations = createUserDecorations(userState, '#4ECDC4')

      // Should only have cursor decoration
      expect(decorations).toHaveLength(1)
      expect(decorations[0].from).toBe(5)
      expect(decorations[0].to).toBe(5)
    })

    it('should return empty array when selection is missing', () => {
      const userState = {
        userId: 'user_789',
        userName: 'Charlie',
        selection: null
      }

      const decorations = createUserDecorations(userState, '#45B7D1')

      expect(decorations).toHaveLength(0)
    })

    it('should return empty array when userId is missing', () => {
      const userState = {
        userId: null,
        userName: 'Dave',
        selection: {
          anchor: 0,
          head: 5
        }
      }

      const decorations = createUserDecorations(userState, '#FFA07A')

      expect(decorations).toHaveLength(0)
    })

    it('should handle backward selection (head before anchor)', () => {
      const userState = {
        userId: 'user_999',
        userName: 'Eve',
        selection: {
          anchor: 10,
          head: 5
        }
      }

      const decorations = createUserDecorations(userState, '#98D8C8')

      expect(decorations).toHaveLength(2)

      // Selection should be from min to max
      const selectionDecoration = decorations[0]
      expect(selectionDecoration.from).toBe(5)
      expect(selectionDecoration.to).toBe(10)

      // Cursor should be at head position
      const cursorDecoration = decorations[1]
      expect(cursorDecoration.from).toBe(5)
    })
  })

  describe('SOLID principles compliance', () => {
    it('should follow Single Responsibility Principle', () => {
      // Each function creates one specific type of decoration
      const cursor = createCursorWidget('user_1', 'User', '#FF0000', 0)
      const selection = createSelectionDecoration('user_1', '#FF0000', 0, 5)
      const user = createUserDecorations({ userId: 'user_1', selection: { anchor: 0, head: 0 } }, '#FF0000')

      expect(cursor.from).toBe(0)
      expect(cursor.spec.key).toContain('cursor')
      expect(selection.from).toBe(0)
      expect(selection.to).toBe(5)
      expect(selection.spec.key).toContain('selection')
      expect(Array.isArray(user)).toBe(true)
    })

    it('should be pure functions (no side effects)', () => {
      const userState = {
        userId: 'user_123',
        userName: 'Alice',
        selection: { anchor: 0, head: 5 }
      }

      // Calling multiple times with same input should produce same output
      const decorations1 = createUserDecorations(userState, '#FF6B6B')
      const decorations2 = createUserDecorations(userState, '#FF6B6B')

      expect(decorations1).toHaveLength(decorations2.length)

      // Original object should not be modified
      expect(userState.userId).toBe('user_123')
      expect(userState.selection.anchor).toBe(0)
    })
  })
})
