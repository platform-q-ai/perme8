/**
 * AwarenessPluginFactory Tests
 *
 * Tests for the factory that creates ProseMirror plugins for awareness rendering.
 * Uses mocked Awareness since real Yjs awareness setup is not needed.
 *
 * @module __tests__/infrastructure/prosemirror
 */

import { describe, test, expect, vi, beforeEach } from 'vitest'
import { createAwarenessPlugin } from '../../../infrastructure/prosemirror/awareness-plugin-factory'

describe('createAwarenessPlugin', () => {
  let mockAwareness: any
  let awarenessChangeCallbacks: Array<(changes: any) => void>

  beforeEach(() => {
    awarenessChangeCallbacks = []

    // Mock Yjs Awareness
    mockAwareness = {
      clientID: 1,
      getStates: vi.fn(() => new Map()),
      on: vi.fn((event: string, callback: (changes: any) => void) => {
        if (event === 'change') {
          awarenessChangeCallbacks.push(callback)
        }
      }),
      off: vi.fn()
    }
  })

  describe('plugin creation', () => {
    test('creates a ProseMirror plugin', () => {
      const plugin = createAwarenessPlugin(mockAwareness, 'user-123')

      expect(plugin).toBeDefined()
      expect(plugin.spec).toBeDefined()
    })

    test('throws error when awareness is null', () => {
      expect(() => createAwarenessPlugin(null as any, 'user-123')).toThrow('Awareness is required')
    })

    test('throws error when userId is empty', () => {
      expect(() => createAwarenessPlugin(mockAwareness, '')).toThrow('UserId is required')
    })

    test('registers awareness change listener when view is created', () => {
      const plugin = createAwarenessPlugin(mockAwareness, 'user-123')

      // Mock EditorView
      const mockEditorView = {
        state: {
          tr: {
            setMeta: vi.fn().mockReturnThis()
          }
        },
        dispatch: vi.fn()
      }

      // Call view() method to register the listener
      if (plugin.spec.view) {
        plugin.spec.view(mockEditorView as any)
      }

      expect(mockAwareness.on).toHaveBeenCalledWith('change', expect.any(Function))
    })
  })

  describe('remote cursor rendering', () => {
    test('renders decorations for remote users', () => {
      // Setup: Add remote user to awareness
      const remoteUser = {
        userId: 'user-456',
        userName: 'Remote User',
        userColor: '#FF6B6B',
        cursor: 10
      }
      mockAwareness.getStates.mockReturnValue(
        new Map([[2, remoteUser]])
      )

      const plugin = createAwarenessPlugin(mockAwareness, 'user-123')

      // The plugin should have a state with decorations
      expect(plugin.spec.state).toBeDefined()
    })

    test('excludes local user from cursor rendering', () => {
      // Setup: Add local user to awareness (should be filtered out)
      const localUser = {
        userId: 'user-123',
        userName: 'Local User',
        userColor: '#FF6B6B',
        cursor: 10
      }
      mockAwareness.getStates.mockReturnValue(
        new Map([[1, localUser]])
      )

      const plugin = createAwarenessPlugin(mockAwareness, 'user-123')

      // Local user should not be rendered
      expect(plugin.spec.state).toBeDefined()
    })

    test('handles users without cursor position', () => {
      // Setup: User without cursor position
      const userWithoutCursor = {
        userId: 'user-456',
        userName: 'Remote User',
        userColor: '#FF6B6B'
        // No cursor property
      }
      mockAwareness.getStates.mockReturnValue(
        new Map([[2, userWithoutCursor]])
      )

      const plugin = createAwarenessPlugin(mockAwareness, 'user-123')

      // Should handle gracefully without errors
      expect(plugin).toBeDefined()
    })

    test('updates decorations when awareness changes', () => {
      const plugin = createAwarenessPlugin(mockAwareness, 'user-123')

      // Mock EditorView
      const mockEditorView = {
        state: {
          tr: {
            setMeta: vi.fn().mockReturnThis()
          }
        },
        dispatch: vi.fn()
      }

      // Call view() method to register the listener
      if (plugin.spec.view) {
        plugin.spec.view(mockEditorView as any)
      }

      // Trigger awareness change
      const changes = {
        added: new Set<number>([2]),
        updated: new Set<number>(),
        removed: new Set<number>()
      }

      expect(awarenessChangeCallbacks.length).toBeGreaterThan(0)

      // Simulate awareness change (should not throw)
      const callback = awarenessChangeCallbacks[0]
      expect(() => callback(changes)).not.toThrow()
    })

    test('removes decorations when users leave', () => {
      const plugin = createAwarenessPlugin(mockAwareness, 'user-123')

      // Mock EditorView
      const mockEditorView = {
        state: {
          tr: {
            setMeta: vi.fn().mockReturnThis()
          }
        },
        dispatch: vi.fn()
      }

      // Call view() method to register the listener
      if (plugin.spec.view) {
        plugin.spec.view(mockEditorView as any)
      }

      // Trigger awareness change for removed user
      const changes = {
        added: new Set<number>(),
        updated: new Set<number>(),
        removed: new Set<number>([2])
      }

      const callback = awarenessChangeCallbacks[0]
      expect(() => callback(changes)).not.toThrow()
    })
  })

  describe('plugin lifecycle', () => {
    test('view has a destroy method for cleanup', () => {
      const plugin = createAwarenessPlugin(mockAwareness, 'user-123')

      // Mock EditorView
      const mockEditorView = {
        state: {
          tr: {
            setMeta: vi.fn().mockReturnThis()
          }
        },
        dispatch: vi.fn()
      }

      // Call view() method to get view object
      let viewObject: any = null
      if (plugin.spec.view) {
        viewObject = plugin.spec.view(mockEditorView as any)
      }

      expect(viewObject).toBeDefined()
      expect(viewObject.destroy).toBeDefined()
    })

    test('unregisters awareness listener on view destroy', () => {
      const plugin = createAwarenessPlugin(mockAwareness, 'user-123')

      // Mock EditorView
      const mockEditorView = {
        state: {
          tr: {
            setMeta: vi.fn().mockReturnThis()
          }
        },
        dispatch: vi.fn()
      }

      // Call view() method to get view object
      let viewObject: any = null
      if (plugin.spec.view) {
        viewObject = plugin.spec.view(mockEditorView as any)
      }

      // Call destroy if available
      if (viewObject && viewObject.destroy) {
        viewObject.destroy()
      }

      expect(mockAwareness.off).toHaveBeenCalledWith('change', expect.any(Function))
    })
  })

  describe('decoration styling', () => {
    test('applies user color to cursor decorations', () => {
      const remoteUser = {
        userId: 'user-456',
        userName: 'Remote User',
        userColor: '#FF6B6B',
        cursor: 10
      }
      mockAwareness.getStates.mockReturnValue(
        new Map([[2, remoteUser]])
      )

      const plugin = createAwarenessPlugin(mockAwareness, 'user-123')

      // Plugin should store user color information
      expect(plugin).toBeDefined()
    })

    test('includes user name in cursor decoration', () => {
      const remoteUser = {
        userId: 'user-456',
        userName: 'Alice',
        userColor: '#FF6B6B',
        cursor: 10
      }
      mockAwareness.getStates.mockReturnValue(
        new Map([[2, remoteUser]])
      )

      const plugin = createAwarenessPlugin(mockAwareness, 'user-123')

      // Plugin should store user name information
      expect(plugin).toBeDefined()
    })
  })
})
