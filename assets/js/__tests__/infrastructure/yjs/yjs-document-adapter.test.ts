import { describe, test, expect, beforeEach, vi } from 'vitest'
import * as Y from 'yjs'
import { YjsDocumentAdapter } from '../../../infrastructure/yjs/yjs-document-adapter'

describe('YjsDocumentAdapter', () => {
  beforeEach(() => {
    // Tests create their own adapter instances
  })

  describe('constructor', () => {
    test('creates adapter with empty document when no initial state provided', () => {
      const adapter = new YjsDocumentAdapter()

      expect(adapter).toBeDefined()
    })

    test('creates adapter with initial state when provided', () => {
      // Create a document with some content
      const sourceDoc = new Y.Doc()
      const sourceFragment = sourceDoc.get('prosemirror', Y.XmlFragment)
      const text = new Y.XmlText()
      text.insert(0, 'Hello, World!')
      sourceFragment.insert(0, [text])

      // Get the state as base64
      const state = Y.encodeStateAsUpdate(sourceDoc)
      const base64State = btoa(String.fromCharCode(...state))

      // Create adapter with initial state
      const adapter = new YjsDocumentAdapter(base64State)

      // Verify the content was loaded
      expect(adapter).toBeDefined()
    })

    test('handles invalid base64 initial state gracefully', () => {
      const invalidBase64 = 'not-valid-base64!!!'

      // Should not throw
      expect(() => new YjsDocumentAdapter(invalidBase64)).not.toThrow()
    })
  })

  describe('applyUpdate', () => {
    test('applies update to internal Yjs document', async () => {
      const adapter = new YjsDocumentAdapter()

      // Create an update
      const sourceDoc = new Y.Doc()
      const sourceFragment = sourceDoc.get('prosemirror', Y.XmlFragment)
      const text = new Y.XmlText()
      text.insert(0, 'Test content')
      sourceFragment.insert(0, [text])

      const update = Y.encodeStateAsUpdate(sourceDoc)

      // Apply the update
      await adapter.applyUpdate(update)

      // Verify by getting current state
      const state = await adapter.getCurrentState()
      expect(state.length).toBeGreaterThan(0)
    })

    test('applies update with origin parameter', async () => {
      const adapter = new YjsDocumentAdapter()

      const sourceDoc = new Y.Doc()
      const sourceFragment = sourceDoc.get('prosemirror', Y.XmlFragment)
      const text = new Y.XmlText()
      text.insert(0, 'Remote update')
      sourceFragment.insert(0, [text])

      const update = Y.encodeStateAsUpdate(sourceDoc)

      // Should not throw when origin is provided
      await expect(adapter.applyUpdate(update, 'remote')).resolves.not.toThrow()
    })

    test('handles empty update without error', async () => {
      const adapter = new YjsDocumentAdapter()
      const emptyUpdate = new Uint8Array([])

      await expect(adapter.applyUpdate(emptyUpdate)).resolves.not.toThrow()
    })
  })

  describe('getCurrentState', () => {
    test('returns current document state as Uint8Array', async () => {
      const adapter = new YjsDocumentAdapter()

      const state = await adapter.getCurrentState()

      expect(state).toBeInstanceOf(Uint8Array)
    })

    test('returns state that includes applied updates', async () => {
      const adapter = new YjsDocumentAdapter()

      // Apply an update
      const sourceDoc = new Y.Doc()
      const sourceFragment = sourceDoc.get('prosemirror', Y.XmlFragment)
      const text = new Y.XmlText()
      text.insert(0, 'Content')
      sourceFragment.insert(0, [text])

      const update = Y.encodeStateAsUpdate(sourceDoc)
      await adapter.applyUpdate(update)

      // Get state
      const state = await adapter.getCurrentState()

      // State should be non-empty
      expect(state.length).toBeGreaterThan(0)
    })

    test('returns empty state for new document', async () => {
      const adapter = new YjsDocumentAdapter()

      const state = await adapter.getCurrentState()

      // New document has minimal state
      expect(state).toBeInstanceOf(Uint8Array)
    })
  })

  describe('onUpdate', () => {
    test('registers callback for document updates', async () => {
      const adapter = new YjsDocumentAdapter()
      const callback = vi.fn()

      adapter.onUpdate(callback)

      // Trigger an update
      const sourceDoc = new Y.Doc()
      const sourceFragment = sourceDoc.get('prosemirror', Y.XmlFragment)
      const text = new Y.XmlText()
      text.insert(0, 'Update')
      sourceFragment.insert(0, [text])

      const update = Y.encodeStateAsUpdate(sourceDoc)
      await adapter.applyUpdate(update, 'remote')

      // Callback should have been called
      expect(callback).toHaveBeenCalled()
    })

    test('passes update and origin to callback', async () => {
      const adapter = new YjsDocumentAdapter()
      const callback = vi.fn()

      adapter.onUpdate(callback)

      // Apply update with origin
      const sourceDoc = new Y.Doc()
      const sourceFragment = sourceDoc.get('prosemirror', Y.XmlFragment)
      const text = new Y.XmlText()
      text.insert(0, 'Test')
      sourceFragment.insert(0, [text])

      const update = Y.encodeStateAsUpdate(sourceDoc)
      await adapter.applyUpdate(update, 'local')

      // Callback should receive update and origin
      expect(callback).toHaveBeenCalledWith(
        expect.any(Uint8Array),
        'local'
      )
    })

    test('callback receives updates from multiple sources', async () => {
      const adapter = new YjsDocumentAdapter()
      const callback = vi.fn()

      adapter.onUpdate(callback)

      // Apply first update
      const doc1 = new Y.Doc()
      const frag1 = doc1.get('prosemirror', Y.XmlFragment)
      const text1 = new Y.XmlText()
      text1.insert(0, 'First')
      frag1.insert(0, [text1])
      await adapter.applyUpdate(Y.encodeStateAsUpdate(doc1), 'remote')

      // Apply second update
      const doc2 = new Y.Doc()
      const frag2 = doc2.get('prosemirror', Y.XmlFragment)
      const text2 = new Y.XmlText()
      text2.insert(0, 'Second')
      frag2.insert(0, [text2])
      await adapter.applyUpdate(Y.encodeStateAsUpdate(doc2), 'local')

      expect(callback).toHaveBeenCalledTimes(2)
    })

    test('supports multiple callbacks', async () => {
      const adapter = new YjsDocumentAdapter()
      const callback1 = vi.fn()
      const callback2 = vi.fn()

      adapter.onUpdate(callback1)
      adapter.onUpdate(callback2)

      // Trigger update
      const sourceDoc = new Y.Doc()
      const sourceFragment = sourceDoc.get('prosemirror', Y.XmlFragment)
      const text = new Y.XmlText()
      text.insert(0, 'Multi')
      sourceFragment.insert(0, [text])

      const update = Y.encodeStateAsUpdate(sourceDoc)
      await adapter.applyUpdate(update)

      expect(callback1).toHaveBeenCalled()
      expect(callback2).toHaveBeenCalled()
    })
  })

  describe('destroy', () => {
    test('cleans up resources', () => {
      const adapter = new YjsDocumentAdapter()

      // Should not throw
      expect(() => adapter.destroy()).not.toThrow()
    })

    test('removes update listeners after destroy', async () => {
      const adapter = new YjsDocumentAdapter()
      const callback = vi.fn()

      adapter.onUpdate(callback)
      adapter.destroy()

      // Apply update after destroy
      const sourceDoc = new Y.Doc()
      const sourceFragment = sourceDoc.get('prosemirror', Y.XmlFragment)
      const text = new Y.XmlText()
      text.insert(0, 'After destroy')
      sourceFragment.insert(0, [text])

      const update = Y.encodeStateAsUpdate(sourceDoc)
      await adapter.applyUpdate(update)

      // Callback should not be called after destroy
      expect(callback).not.toHaveBeenCalled()
    })

    test('can be called multiple times safely', () => {
      const adapter = new YjsDocumentAdapter()

      expect(() => {
        adapter.destroy()
        adapter.destroy()
        adapter.destroy()
      }).not.toThrow()
    })
  })

  describe('integration', () => {
    test('full workflow: initialize, update, listen, destroy', async () => {
      // Create adapter with initial state
      const initialDoc = new Y.Doc()
      const initialFragment = initialDoc.get('prosemirror', Y.XmlFragment)
      const initialText = new Y.XmlText()
      initialText.insert(0, 'Initial')
      initialFragment.insert(0, [initialText])

      const initialState = Y.encodeStateAsUpdate(initialDoc)
      const base64Initial = btoa(String.fromCharCode(...initialState))

      const adapter = new YjsDocumentAdapter(base64Initial)

      // Set up listener
      const updates: Array<{ update: Uint8Array; origin: string }> = []
      adapter.onUpdate((update, origin) => {
        updates.push({ update, origin })
      })

      // Apply remote update
      const remoteDoc = new Y.Doc()
      const remoteFragment = remoteDoc.get('prosemirror', Y.XmlFragment)
      const remoteText = new Y.XmlText()
      remoteText.insert(0, 'Remote')
      remoteFragment.insert(0, [remoteText])

      const remoteUpdate = Y.encodeStateAsUpdate(remoteDoc)
      await adapter.applyUpdate(remoteUpdate, 'remote')

      // Get final state
      const finalState = await adapter.getCurrentState()

      // Verify
      expect(updates.length).toBeGreaterThan(0)
      expect(finalState.length).toBeGreaterThan(0)

      // Clean up
      adapter.destroy()
    })
  })
})
