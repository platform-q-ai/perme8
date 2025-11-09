import { describe, it, expect, beforeEach, vi } from 'vitest'
import { createAwarenessPlugin, awarenessPluginKey } from './awareness-plugin'
import { DecorationSet } from '@milkdown/prose/view'

// Mock DecorationSet to avoid needing a real ProseMirror document
vi.mock('@milkdown/prose/view', () => {
  const mockDecorationSet = {
    decorations: [],
    map: vi.fn(function() { return this })
  }
  return {
    DecorationSet: {
      empty: mockDecorationSet,
      create: vi.fn((doc, decorations) => ({
        doc,
        decorations,
        map: vi.fn(() => mockDecorationSet)
      }))
    }
  }
})

// Mock user-colors module
vi.mock('./user-colors', () => ({
  getUserColor: vi.fn((userId) => {
    // Return different colors for different users
    const colors = {
      'user_123': '#FF0000',
      'user_456': '#00FF00',
      'user_789': '#0000FF'
    }
    return colors[userId] || '#CCCCCC'
  })
}))

// Mock cursor-decorations module
vi.mock('./cursor-decorations', () => ({
  createUserDecorations: vi.fn((state, color) => {
    // Return mock decorations
    if (!state.selection) return []

    return [{
      type: 'cursor',
      from: state.selection.anchor,
      to: state.selection.head,
      userId: state.userId,
      color: color
    }]
  })
}))

describe('Awareness Plugin', () => {
  let mockAwareness
  let mockDoc
  let mockTransaction

  beforeEach(() => {
    // Clear all mocks before each test
    vi.clearAllMocks()

    // Mock Awareness instance
    mockAwareness = {
      getStates: vi.fn(() => new Map())
    }

    // Mock ProseMirror document
    mockDoc = {
      nodeSize: 100
    }

    // Mock ProseMirror transaction
    mockTransaction = {
      doc: mockDoc,
      getMeta: vi.fn(),
      mapping: {
        maps: []
      }
    }
  })

  describe('createAwarenessPlugin', () => {
    it('should create a plugin with correct key', () => {
      const plugin = createAwarenessPlugin(mockAwareness, 'user_local')

      expect(plugin.spec.key).toBe(awarenessPluginKey)
    })

    it('should initialize with empty decoration set', () => {
      const plugin = createAwarenessPlugin(mockAwareness, 'user_local')
      const state = plugin.spec.state.init()

      // Check it returns the empty DecorationSet mock
      expect(state).toBe(DecorationSet.empty)
    })

    it('should filter out local user from decorations', async () => {
      const { getUserColor } = await import('./user-colors')
      const { createUserDecorations } = await import('./cursor-decorations')

      // Setup awareness states with local and remote users
      const awarenessStates = new Map([
        [1, { userId: 'user_local', userName: 'Local', selection: { anchor: 0, head: 5 } }],
        [2, { userId: 'user_remote', userName: 'Remote', selection: { anchor: 10, head: 15 } }]
      ])

      mockAwareness.getStates.mockReturnValue(awarenessStates)

      const plugin = createAwarenessPlugin(mockAwareness, 'user_local')

      // Trigger awareness change
      mockTransaction.getMeta.mockReturnValue(true)
      const decorationSet = plugin.spec.state.apply(mockTransaction, DecorationSet.empty)

      // Should call getUserColor and createUserDecorations only for remote user
      expect(getUserColor).toHaveBeenCalledWith('user_remote')
      expect(getUserColor).not.toHaveBeenCalledWith('user_local')
    })

    it('should create decorations when awareness changes', () => {
      const awarenessStates = new Map([
        [2, { userId: 'user_456', userName: 'User 2', selection: { anchor: 10, head: 15 } }]
      ])

      mockAwareness.getStates.mockReturnValue(awarenessStates)

      const plugin = createAwarenessPlugin(mockAwareness, 'user_local')

      // Trigger awareness change
      mockTransaction.getMeta.mockReturnValue(true)
      const decorationSet = plugin.spec.state.apply(mockTransaction, DecorationSet.empty)

      expect(mockAwareness.getStates).toHaveBeenCalled()
      expect(mockTransaction.getMeta).toHaveBeenCalledWith('awarenessChanged')
    })

    it('should map decorations through document changes', () => {
      const plugin = createAwarenessPlugin(mockAwareness, 'user_local')

      // Initial state with decorations
      const initialSet = DecorationSet.empty
      const mapSpy = vi.spyOn(initialSet, 'map')

      // No awareness change - should map decorations
      mockTransaction.getMeta.mockReturnValue(false)
      plugin.spec.state.apply(mockTransaction, initialSet)

      expect(mapSpy).toHaveBeenCalledWith(mockTransaction.mapping, mockTransaction.doc)
    })

    it('should create new decoration set when awareness changes', () => {
      const awarenessStates = new Map([
        [3, { userId: 'user_789', userName: 'User 3', selection: { anchor: 20, head: 25 } }]
      ])

      mockAwareness.getStates.mockReturnValue(awarenessStates)

      const plugin = createAwarenessPlugin(mockAwareness, 'user_local')

      // Trigger awareness change
      mockTransaction.getMeta.mockReturnValue(true)
      const decorationSet = plugin.spec.state.apply(mockTransaction, DecorationSet.empty)

      // Should create new decoration set with doc and decorations
      expect(decorationSet).toBeDefined()
      expect(decorationSet.doc).toBe(mockDoc)
      expect(decorationSet.decorations).toBeDefined()
    })

    it('should provide decorations via props', () => {
      const plugin = createAwarenessPlugin(mockAwareness, 'user_local')

      expect(plugin.spec.props.decorations).toBeDefined()
      expect(typeof plugin.spec.props.decorations).toBe('function')
    })

    it('should handle multiple remote users', async () => {
      const { createUserDecorations } = await import('./cursor-decorations')

      const awarenessStates = new Map([
        [1, { userId: 'user_local', userName: 'Local', selection: { anchor: 0, head: 5 } }],
        [2, { userId: 'user_456', userName: 'User 2', selection: { anchor: 10, head: 15 } }],
        [3, { userId: 'user_789', userName: 'User 3', selection: { anchor: 20, head: 25 } }]
      ])

      mockAwareness.getStates.mockReturnValue(awarenessStates)

      const plugin = createAwarenessPlugin(mockAwareness, 'user_local')

      // Trigger awareness change
      mockTransaction.getMeta.mockReturnValue(true)
      plugin.spec.state.apply(mockTransaction, DecorationSet.empty)

      // Should create decorations for 2 remote users (excluding local)
      expect(createUserDecorations).toHaveBeenCalledTimes(2)
    })

    it('should handle users without selection', async () => {
      const { createUserDecorations } = await import('./cursor-decorations')

      const awarenessStates = new Map([
        [2, { userId: 'user_456', userName: 'User 2', selection: null }]
      ])

      mockAwareness.getStates.mockReturnValue(awarenessStates)

      const plugin = createAwarenessPlugin(mockAwareness, 'user_local')

      // Trigger awareness change
      mockTransaction.getMeta.mockReturnValue(true)
      plugin.spec.state.apply(mockTransaction, DecorationSet.empty)

      // Should still call createUserDecorations even with null selection
      expect(createUserDecorations).toHaveBeenCalled()
    })

    it('should export awarenessPluginKey', () => {
      expect(awarenessPluginKey).toBeDefined()
      expect(awarenessPluginKey.key).toBe('awareness$')
    })
  })
})
