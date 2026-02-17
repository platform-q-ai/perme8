import { describe, test, expect, beforeEach, vi } from 'vitest'
import * as Y from 'yjs'
import { Awareness, encodeAwarenessUpdate } from 'y-protocols/awareness'
import { YjsAwarenessAdapter } from '../../../infrastructure/yjs/yjs-awareness-adapter'
import type { AwarenessChanges } from '../../../application/interfaces/awareness-adapter.interface'

describe('YjsAwarenessAdapter', () => {
  let ydoc: Y.Doc
  let awareness: Awareness
  let adapter: YjsAwarenessAdapter

  beforeEach(() => {
    ydoc = new Y.Doc()
    awareness = new Awareness(ydoc)
    adapter = new YjsAwarenessAdapter(awareness)
  })

  describe('constructor', () => {
    test('creates adapter with Awareness instance', () => {
      const adapter = new YjsAwarenessAdapter(awareness)

      expect(adapter).toBeDefined()
    })

    test('throws error when Awareness is null', () => {
      expect(() => new YjsAwarenessAdapter(null as any)).toThrow()
    })

    test('throws error when Awareness is undefined', () => {
      expect(() => new YjsAwarenessAdapter(undefined as any)).toThrow()
    })
  })

  describe('setLocalState', () => {
    test('sets local awareness state', () => {
      const state = {
        userId: 'user-123',
        userName: 'John Doe',
        cursor: 42
      }

      adapter.setLocalState(state)

      // Verify state was set
      const localState = awareness.getLocalState()
      expect(localState).toEqual(state)
    })

    test('updates existing local state', () => {
      adapter.setLocalState({ userId: 'user-1', cursor: 10 })
      adapter.setLocalState({ userId: 'user-1', cursor: 20 })

      const localState = awareness.getLocalState()
      expect(localState).toEqual({ userId: 'user-1', cursor: 20 })
    })

    test('handles empty state object', () => {
      expect(() => adapter.setLocalState({})).not.toThrow()
    })

    test('handles state with nested objects', () => {
      const state = {
        userId: 'user-1',
        selection: { anchor: 10, head: 20 }
      }

      adapter.setLocalState(state)

      const localState = awareness.getLocalState()
      expect(localState).toEqual(state)
    })
  })

  describe('onAwarenessChange', () => {
    test('registers callback for awareness changes', () => {
      const callback = vi.fn()

      adapter.onAwarenessChange(callback)

      // Trigger awareness change
      adapter.setLocalState({ userId: 'user-1' })

      // Callback should be called
      expect(callback).toHaveBeenCalled()
    })

    test('passes AwarenessChanges to callback', () => {
      const callback = vi.fn()

      adapter.onAwarenessChange(callback)
      adapter.setLocalState({ userId: 'user-1' })

      // Callback should receive changes object
      expect(callback).toHaveBeenCalledWith(
        expect.objectContaining({
          added: expect.any(Array),
          updated: expect.any(Array),
          removed: expect.any(Array)
        })
      )
    })

    test('callback receives added clients', () => {
      const callback = vi.fn()
      adapter.onAwarenessChange(callback)

      // Set local state (Yjs reports this as "updated" for existing client, not "added")
      adapter.setLocalState({ userId: 'user-1' })

      const changes = callback.mock.calls[0][0] as AwarenessChanges
      // The local client is "updated" when state is set (not "added")
      expect(changes.updated.length).toBeGreaterThan(0)
    })

    test('callback receives updated clients', () => {
      const callback = vi.fn()

      // Set initial state
      adapter.setLocalState({ userId: 'user-1', cursor: 10 })

      // Register callback after initial state
      adapter.onAwarenessChange(callback)

      // Update state
      adapter.setLocalState({ userId: 'user-1', cursor: 20 })

      const changes = callback.mock.calls[0][0] as AwarenessChanges
      expect(changes.updated.length).toBeGreaterThan(0)
    })

    test('supports multiple callbacks', () => {
      const callback1 = vi.fn()
      const callback2 = vi.fn()

      adapter.onAwarenessChange(callback1)
      adapter.onAwarenessChange(callback2)

      adapter.setLocalState({ userId: 'user-1' })

      expect(callback1).toHaveBeenCalled()
      expect(callback2).toHaveBeenCalled()
    })

    test('callbacks receive same change event', () => {
      const callback1 = vi.fn()
      const callback2 = vi.fn()

      adapter.onAwarenessChange(callback1)
      adapter.onAwarenessChange(callback2)

      adapter.setLocalState({ userId: 'user-1' })

      const changes1 = callback1.mock.calls[0][0]
      const changes2 = callback2.mock.calls[0][0]

      expect(changes1).toEqual(changes2)
    })
  })

  describe('encodeUpdate', () => {
    test('encodes awareness update for client IDs', () => {
      adapter.setLocalState({ userId: 'user-1' })

      const clientId = awareness.clientID
      const update = adapter.encodeUpdate([clientId])

      expect(update).toBeInstanceOf(Uint8Array)
      expect(update.length).toBeGreaterThan(0)
    })

    test('handles empty client ID array', () => {
      const update = adapter.encodeUpdate([])

      expect(update).toBeInstanceOf(Uint8Array)
    })

    test('encodes multiple client IDs', () => {
      // Set local state for local client
      adapter.setLocalState({ userId: 'user-1' })

      // Create another awareness with state and merge it
      const otherDoc = new Y.Doc()
      const otherAwareness = new Awareness(otherDoc)
      otherAwareness.setLocalState({ userId: 'user-2' })

      // Apply the other awareness to this one
      const otherUpdate = encodeAwarenessUpdate(otherAwareness, [otherAwareness.clientID])
      adapter.applyUpdate(otherUpdate)

      // Now we have two clients with state
      const clientId1 = awareness.clientID
      const clientId2 = otherAwareness.clientID

      const update = adapter.encodeUpdate([clientId1, clientId2])

      expect(update).toBeInstanceOf(Uint8Array)
    })

    test('encoded update can be applied to another awareness', () => {
      adapter.setLocalState({ userId: 'user-1', userName: 'John' })

      const clientId = awareness.clientID
      const update = adapter.encodeUpdate([clientId])

      // Create another awareness and apply update
      const otherDoc = new Y.Doc()
      const otherAwareness = new Awareness(otherDoc)
      const otherAdapter = new YjsAwarenessAdapter(otherAwareness)

      otherAdapter.applyUpdate(update)

      // Verify state was transferred
      const states = otherAwareness.getStates()
      const state = states.get(clientId)
      expect(state).toEqual({ userId: 'user-1', userName: 'John' })
    })
  })

  describe('applyUpdate', () => {
    test('applies awareness update', () => {
      // Create update from another awareness
      const sourceDoc = new Y.Doc()
      const sourceAwareness = new Awareness(sourceDoc)
      sourceAwareness.setLocalState({ userId: 'remote-user' })

      const sourceClientId = sourceAwareness.clientID
      const update = encodeAwarenessUpdate(sourceAwareness, [sourceClientId])

      // Apply update
      adapter.applyUpdate(update)

      // Verify state was applied
      const states = awareness.getStates()
      const state = states.get(sourceClientId)
      expect(state).toEqual({ userId: 'remote-user' })
    })

    test('applies update with origin parameter', () => {
      const sourceDoc = new Y.Doc()
      const sourceAwareness = new Awareness(sourceDoc)
      sourceAwareness.setLocalState({ userId: 'remote' })

      const update = encodeAwarenessUpdate(sourceAwareness, [sourceAwareness.clientID])

      // Should not throw when origin is provided
      expect(() => adapter.applyUpdate(update, 'remote')).not.toThrow()
    })

    test('triggers awareness change callback', () => {
      const callback = vi.fn()
      adapter.onAwarenessChange(callback)

      // Create and apply update
      const sourceDoc = new Y.Doc()
      const sourceAwareness = new Awareness(sourceDoc)
      sourceAwareness.setLocalState({ userId: 'remote-user' })

      const update = encodeAwarenessUpdate(sourceAwareness, [sourceAwareness.clientID])
      adapter.applyUpdate(update)

      // Callback should be called
      expect(callback).toHaveBeenCalled()
    })

    test('handles empty update', () => {
      const emptyUpdate = new Uint8Array([])

      expect(() => adapter.applyUpdate(emptyUpdate)).not.toThrow()
    })

    test('merges multiple updates', () => {
      // Apply first update
      const doc1 = new Y.Doc()
      const awareness1 = new Awareness(doc1)
      awareness1.setLocalState({ userId: 'user-1' })
      const update1 = encodeAwarenessUpdate(awareness1, [awareness1.clientID])
      adapter.applyUpdate(update1)

      // Apply second update
      const doc2 = new Y.Doc()
      const awareness2 = new Awareness(doc2)
      awareness2.setLocalState({ userId: 'user-2' })
      const update2 = encodeAwarenessUpdate(awareness2, [awareness2.clientID])
      adapter.applyUpdate(update2)

      // Both states should exist
      const states = awareness.getStates()
      expect(states.size).toBeGreaterThanOrEqual(2)
    })
  })

  describe('removeUserByUserId', () => {
    test('removes awareness state for a remote user by userId', () => {
      // Simulate a remote user's awareness state
      const remoteDoc = new Y.Doc()
      const remoteAwareness = new Awareness(remoteDoc)
      remoteAwareness.setLocalState({ userId: 'user-remote', userName: 'Remote User' })

      // Apply the remote user's state to our awareness
      const update = encodeAwarenessUpdate(remoteAwareness, [remoteAwareness.clientID])
      adapter.applyUpdate(update)

      // Verify the remote user's state exists
      const statesBefore = awareness.getStates()
      let found = false
      statesBefore.forEach((state) => {
        if (state && (state as any).userId === 'user-remote') found = true
      })
      expect(found).toBe(true)

      // Remove by userId
      adapter.removeUserByUserId('user-remote')

      // State should be gone
      const statesAfter = awareness.getStates()
      let foundAfter = false
      statesAfter.forEach((state) => {
        if (state && (state as any).userId === 'user-remote') foundAfter = true
      })
      expect(foundAfter).toBe(false)
    })

    test('does nothing for unknown userId', () => {
      expect(() => adapter.removeUserByUserId('nonexistent')).not.toThrow()
    })

    test('does nothing after destroy', () => {
      adapter.destroy()
      // Should not throw even after destroy
      expect(() => adapter.removeUserByUserId('user-1')).not.toThrow()
    })

    test('fires awareness change callback with removed clients', () => {
      const callback = vi.fn()

      // Add a remote user
      const remoteDoc = new Y.Doc()
      const remoteAwareness = new Awareness(remoteDoc)
      remoteAwareness.setLocalState({ userId: 'user-remote', userName: 'Remote User' })
      const update = encodeAwarenessUpdate(remoteAwareness, [remoteAwareness.clientID])
      adapter.applyUpdate(update)

      adapter.onAwarenessChange(callback)
      callback.mockClear()

      adapter.removeUserByUserId('user-remote')

      expect(callback).toHaveBeenCalledTimes(1)
      const changes = callback.mock.calls[0][0] as AwarenessChanges
      expect(changes.removed).toContain(remoteAwareness.clientID)
    })
  })

  describe('destroy', () => {
    test('cleans up resources', () => {
      expect(() => adapter.destroy()).not.toThrow()
    })

    test('removes awareness change listeners after destroy', () => {
      const callback = vi.fn()

      adapter.onAwarenessChange(callback)
      adapter.destroy()

      // Record call count after destroy (destroy itself may fire a removal event)
      const callCountAfterDestroy = callback.mock.calls.length

      // Trigger awareness change after destroy via raw awareness API
      awareness.setLocalState({ userId: 'user-1' })

      // No additional calls should happen after destroy
      expect(callback).toHaveBeenCalledTimes(callCountAfterDestroy)
    })

    test('can be called multiple times safely', () => {
      expect(() => {
        adapter.destroy()
        adapter.destroy()
        adapter.destroy()
      }).not.toThrow()
    })

    test('removes local awareness state on destroy', () => {
      // Set local state first
      adapter.setLocalState({ userId: 'user-1', cursor: 42 })
      const clientId = awareness.clientID

      // Verify state exists before destroy
      expect(awareness.getStates().get(clientId)).toBeDefined()

      adapter.destroy()

      // Local state should be null after destroy (removed)
      expect(awareness.getLocalState()).toBeNull()
    })

    test('fires removal change event before cleaning up listeners', () => {
      const callback = vi.fn()
      adapter.setLocalState({ userId: 'user-1' })
      adapter.onAwarenessChange(callback)

      // Clear previous calls from setLocalState
      callback.mockClear()

      adapter.destroy()

      // Callback should be called with the local client in the removed set
      expect(callback).toHaveBeenCalledTimes(1)
      const changes = callback.mock.calls[0][0] as AwarenessChanges
      expect(changes.removed).toContain(awareness.clientID)
    })

    test('prevents setLocalState after destroy', () => {
      adapter.destroy()

      expect(() => adapter.setLocalState({ userId: 'user-1' })).toThrow('destroyed')
    })

    test('prevents encodeUpdate after destroy', () => {
      adapter.destroy()

      expect(() => adapter.encodeUpdate([1])).toThrow('destroyed')
    })

    test('prevents applyUpdate after destroy', () => {
      adapter.destroy()

      const update = new Uint8Array([])
      expect(() => adapter.applyUpdate(update)).toThrow('destroyed')
    })
  })

  describe('integration', () => {
    test('full workflow: set state, encode, apply, listen, destroy', () => {
      // Set up listener
      const changes: AwarenessChanges[] = []
      adapter.onAwarenessChange((change) => {
        changes.push(change)
      })

      // Set local state
      adapter.setLocalState({ userId: 'user-1', userName: 'John' })

      // Encode update
      const clientId = awareness.clientID
      const update = adapter.encodeUpdate([clientId])

      // Create another adapter and apply update
      const otherDoc = new Y.Doc()
      const otherAwareness = new Awareness(otherDoc)
      const otherAdapter = new YjsAwarenessAdapter(otherAwareness)

      otherAdapter.applyUpdate(update)

      // Verify
      expect(changes.length).toBeGreaterThan(0)
      const otherState = otherAwareness.getStates().get(clientId)
      expect(otherState).toEqual({ userId: 'user-1', userName: 'John' })

      // Clean up
      adapter.destroy()
      otherAdapter.destroy()
    })

    test('bidirectional awareness sync', () => {
      // Create two adapters
      const doc1 = new Y.Doc()
      const awareness1 = new Awareness(doc1)
      const adapter1 = new YjsAwarenessAdapter(awareness1)

      const doc2 = new Y.Doc()
      const awareness2 = new Awareness(doc2)
      const adapter2 = new YjsAwarenessAdapter(awareness2)

      // Set state on adapter1
      adapter1.setLocalState({ userId: 'user-1' })

      // Sync to adapter2
      const update1 = adapter1.encodeUpdate([awareness1.clientID])
      adapter2.applyUpdate(update1)

      // Set state on adapter2
      adapter2.setLocalState({ userId: 'user-2' })

      // Sync to adapter1
      const update2 = adapter2.encodeUpdate([awareness2.clientID])
      adapter1.applyUpdate(update2)

      // Both adapters should have both states
      expect(awareness1.getStates().size).toBe(2)
      expect(awareness2.getStates().size).toBe(2)

      // Clean up
      adapter1.destroy()
      adapter2.destroy()
    })
  })
})
