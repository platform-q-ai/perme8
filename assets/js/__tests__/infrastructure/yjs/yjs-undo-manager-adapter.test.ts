import { describe, test, expect, beforeEach } from 'vitest'
import * as Y from 'yjs'
import { YjsUndoManagerAdapter } from '../../../infrastructure/yjs/yjs-undo-manager-adapter'

describe('YjsUndoManagerAdapter', () => {
  let ydoc: Y.Doc
  let yXmlFragment: Y.XmlFragment
  let binding: any
  let adapter: YjsUndoManagerAdapter

  beforeEach(() => {
    ydoc = new Y.Doc()
    yXmlFragment = ydoc.get('prosemirror', Y.XmlFragment)
    // Simulate a binding object (used by y-prosemirror)
    binding = { doc: ydoc }
    adapter = new YjsUndoManagerAdapter(yXmlFragment, binding)
  })

  describe('constructor', () => {
    test('creates adapter with Y.XmlFragment and binding', () => {
      const adapter = new YjsUndoManagerAdapter(yXmlFragment, binding)

      expect(adapter).toBeDefined()
    })

    test('throws error when yXmlFragment is null', () => {
      expect(() => new YjsUndoManagerAdapter(null as any, binding)).toThrow()
    })

    test('throws error when binding is null', () => {
      expect(() => new YjsUndoManagerAdapter(yXmlFragment, null as any)).toThrow()
    })
  })

  describe('undo', () => {
    test('undoes last change', () => {
      // Make a change
      ydoc.transact(() => {
        const text = new Y.XmlText()
        text.insert(0, 'Hello')
        yXmlFragment.insert(0, [text])
      }, binding)

      // Undo the change
      adapter.undo()

      // Fragment should be empty
      expect(yXmlFragment.length).toBe(0)
    })

    test('undoes multiple changes in reverse order', () => {
      // Make first change
      ydoc.transact(() => {
        const text1 = new Y.XmlText()
        text1.insert(0, 'First')
        yXmlFragment.insert(0, [text1])
      }, binding)

      // Make second change
      ydoc.transact(() => {
        const text2 = new Y.XmlText()
        text2.insert(0, 'Second')
        yXmlFragment.insert(1, [text2])
      }, binding)

      // Fragment should have 2 elements
      expect(yXmlFragment.length).toBe(2)

      // Undo second change
      adapter.undo()
      expect(yXmlFragment.length).toBe(1)

      // Undo first change
      adapter.undo()
      expect(yXmlFragment.length).toBe(0)
    })

    test('does nothing when undo stack is empty', () => {
      // No changes made, undo should not throw
      expect(() => adapter.undo()).not.toThrow()
    })

    test('does not undo remote changes', () => {
      // Make local change with binding as origin
      ydoc.transact(() => {
        const text1 = new Y.XmlText()
        text1.insert(0, 'Local')
        yXmlFragment.insert(0, [text1])
      }, binding)

      // Make remote change with different origin
      ydoc.transact(() => {
        const text2 = new Y.XmlText()
        text2.insert(0, 'Remote')
        yXmlFragment.insert(1, [text2])
      }, 'remote')

      expect(yXmlFragment.length).toBe(2)

      // Undo should only undo local change
      adapter.undo()
      expect(yXmlFragment.length).toBe(1)

      // Remote change should remain
      const remainingText = yXmlFragment.get(0) as Y.XmlText
      expect(remainingText.toString()).toBe('Remote')
    })
  })

  describe('redo', () => {
    test('redoes undone change', () => {
      // Make a change
      ydoc.transact(() => {
        const text = new Y.XmlText()
        text.insert(0, 'Hello')
        yXmlFragment.insert(0, [text])
      }, binding)

      // Undo
      adapter.undo()
      expect(yXmlFragment.length).toBe(0)

      // Redo
      adapter.redo()
      expect(yXmlFragment.length).toBe(1)
    })

    test('redoes multiple undone changes in correct order', () => {
      // Make two changes
      ydoc.transact(() => {
        const text1 = new Y.XmlText()
        text1.insert(0, 'First')
        yXmlFragment.insert(0, [text1])
      }, binding)

      ydoc.transact(() => {
        const text2 = new Y.XmlText()
        text2.insert(0, 'Second')
        yXmlFragment.insert(1, [text2])
      }, binding)

      // Undo both
      adapter.undo()
      adapter.undo()
      expect(yXmlFragment.length).toBe(0)

      // Redo first
      adapter.redo()
      expect(yXmlFragment.length).toBe(1)

      // Redo second
      adapter.redo()
      expect(yXmlFragment.length).toBe(2)
    })

    test('does nothing when redo stack is empty', () => {
      // No undone changes, redo should not throw
      expect(() => adapter.redo()).not.toThrow()
    })

    test('clears redo stack on new change', () => {
      // Make a change
      ydoc.transact(() => {
        const text1 = new Y.XmlText()
        text1.insert(0, 'First')
        yXmlFragment.insert(0, [text1])
      }, binding)

      // Undo
      adapter.undo()
      expect(yXmlFragment.length).toBe(0)

      // Make new change (should clear redo stack)
      ydoc.transact(() => {
        const text2 = new Y.XmlText()
        text2.insert(0, 'New')
        yXmlFragment.insert(0, [text2])
      }, binding)

      // Redo should do nothing (stack was cleared)
      adapter.redo()
      expect(yXmlFragment.length).toBe(1)
    })
  })

  describe('canUndo', () => {
    test('returns false when undo stack is empty', () => {
      expect(adapter.canUndo()).toBe(false)
    })

    test('returns true after making a change', () => {
      ydoc.transact(() => {
        const text = new Y.XmlText()
        text.insert(0, 'Content')
        yXmlFragment.insert(0, [text])
      }, binding)

      expect(adapter.canUndo()).toBe(true)
    })

    test('returns false after undoing all changes', () => {
      ydoc.transact(() => {
        const text = new Y.XmlText()
        text.insert(0, 'Content')
        yXmlFragment.insert(0, [text])
      }, binding)

      adapter.undo()

      expect(adapter.canUndo()).toBe(false)
    })

    test('returns false for remote changes', () => {
      // Make remote change (not tracked)
      ydoc.transact(() => {
        const text = new Y.XmlText()
        text.insert(0, 'Remote')
        yXmlFragment.insert(0, [text])
      }, 'remote')

      expect(adapter.canUndo()).toBe(false)
    })
  })

  describe('canRedo', () => {
    test('returns false when redo stack is empty', () => {
      expect(adapter.canRedo()).toBe(false)
    })

    test('returns true after undoing a change', () => {
      ydoc.transact(() => {
        const text = new Y.XmlText()
        text.insert(0, 'Content')
        yXmlFragment.insert(0, [text])
      }, binding)

      adapter.undo()

      expect(adapter.canRedo()).toBe(true)
    })

    test('returns false after redoing all changes', () => {
      ydoc.transact(() => {
        const text = new Y.XmlText()
        text.insert(0, 'Content')
        yXmlFragment.insert(0, [text])
      }, binding)

      adapter.undo()
      adapter.redo()

      expect(adapter.canRedo()).toBe(false)
    })

    test('returns false after new change clears redo stack', () => {
      ydoc.transact(() => {
        const text = new Y.XmlText()
        text.insert(0, 'First')
        yXmlFragment.insert(0, [text])
      }, binding)

      adapter.undo()

      ydoc.transact(() => {
        const text = new Y.XmlText()
        text.insert(0, 'Second')
        yXmlFragment.insert(0, [text])
      }, binding)

      expect(adapter.canRedo()).toBe(false)
    })
  })

  describe('clear', () => {
    test('clears undo and redo stacks', () => {
      // Make changes
      ydoc.transact(() => {
        const text = new Y.XmlText()
        text.insert(0, 'Content')
        yXmlFragment.insert(0, [text])
      }, binding)

      adapter.undo()

      expect(adapter.canUndo()).toBe(false)
      expect(adapter.canRedo()).toBe(true)

      // Clear stacks
      adapter.clear()

      expect(adapter.canUndo()).toBe(false)
      expect(adapter.canRedo()).toBe(false)
    })

    test('can be called multiple times safely', () => {
      expect(() => {
        adapter.clear()
        adapter.clear()
        adapter.clear()
      }).not.toThrow()
    })
  })

  describe('destroy', () => {
    test('cleans up resources', () => {
      expect(() => adapter.destroy()).not.toThrow()
    })

    test('prevents undo after destroy', () => {
      ydoc.transact(() => {
        const text = new Y.XmlText()
        text.insert(0, 'Content')
        yXmlFragment.insert(0, [text])
      }, binding)

      adapter.destroy()

      // Operations after destroy should not throw but should do nothing
      expect(() => adapter.undo()).not.toThrow()
      // Fragment should not be affected
      expect(yXmlFragment.length).toBe(1)
    })

    test('prevents redo after destroy', () => {
      ydoc.transact(() => {
        const text = new Y.XmlText()
        text.insert(0, 'Content')
        yXmlFragment.insert(0, [text])
      }, binding)

      adapter.undo()
      adapter.destroy()

      expect(() => adapter.redo()).not.toThrow()
      expect(yXmlFragment.length).toBe(0)
    })

    test('can be called multiple times safely', () => {
      expect(() => {
        adapter.destroy()
        adapter.destroy()
        adapter.destroy()
      }).not.toThrow()
    })
  })

  describe('integration', () => {
    test('full undo/redo workflow', () => {
      // Make three changes
      ydoc.transact(() => {
        const text1 = new Y.XmlText()
        text1.insert(0, 'First')
        yXmlFragment.insert(0, [text1])
      }, binding)

      ydoc.transact(() => {
        const text2 = new Y.XmlText()
        text2.insert(0, 'Second')
        yXmlFragment.insert(1, [text2])
      }, binding)

      ydoc.transact(() => {
        const text3 = new Y.XmlText()
        text3.insert(0, 'Third')
        yXmlFragment.insert(2, [text3])
      }, binding)

      expect(yXmlFragment.length).toBe(3)
      expect(adapter.canUndo()).toBe(true)
      expect(adapter.canRedo()).toBe(false)

      // Undo twice
      adapter.undo()
      adapter.undo()

      expect(yXmlFragment.length).toBe(1)
      expect(adapter.canUndo()).toBe(true)
      expect(adapter.canRedo()).toBe(true)

      // Redo once
      adapter.redo()

      expect(yXmlFragment.length).toBe(2)
      expect(adapter.canUndo()).toBe(true)
      expect(adapter.canRedo()).toBe(true)

      // Clear and verify
      adapter.clear()

      expect(adapter.canUndo()).toBe(false)
      expect(adapter.canRedo()).toBe(false)

      // Clean up
      adapter.destroy()
    })

    test('handles mix of local and remote changes', () => {
      // Local change
      ydoc.transact(() => {
        const text1 = new Y.XmlText()
        text1.insert(0, 'Local1')
        yXmlFragment.insert(0, [text1])
      }, binding)

      // Remote change
      ydoc.transact(() => {
        const text2 = new Y.XmlText()
        text2.insert(0, 'Remote1')
        yXmlFragment.insert(1, [text2])
      }, 'remote')

      // Local change
      ydoc.transact(() => {
        const text3 = new Y.XmlText()
        text3.insert(0, 'Local2')
        yXmlFragment.insert(2, [text3])
      }, binding)

      expect(yXmlFragment.length).toBe(3)

      // Undo should only undo local changes
      adapter.undo()
      expect(yXmlFragment.length).toBe(2)

      adapter.undo()
      expect(yXmlFragment.length).toBe(1)

      // Remote change should remain
      const remaining = yXmlFragment.get(0) as Y.XmlText
      expect(remaining.toString()).toBe('Remote1')
    })
  })
})
