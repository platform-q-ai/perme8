import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { AIAssistantManager } from './ai-integration'

describe('AIAssistantManager - Integration', () => {
  let aiAssistant
  let mockView
  let mockSchema
  let mockPushEvent

  beforeEach(() => {
    // Create minimal mocks
    mockSchema = {
      nodes: {
        paragraph: { create: vi.fn() },
        text: vi.fn()
      }
    }

    mockView = {
      state: {
        doc: {
          content: { size: 10 },
          descendants: vi.fn() // Mock descendants for cancelQuery
        },
        schema: mockSchema,
        tr: {
          delete: vi.fn().mockReturnThis(),
          insert: vi.fn().mockReturnThis(),
          insertText: vi.fn().mockReturnThis()
        }
      },
      dispatch: vi.fn()
    }

    mockPushEvent = vi.fn()

    aiAssistant = new AIAssistantManager({
      view: mockView,
      schema: mockSchema,
      pushEvent: mockPushEvent
    })
  })

  afterEach(() => {
    if (aiAssistant) {
      aiAssistant.destroy()
    }
  })

  describe('AI query lifecycle', () => {
    it('should track active queries', () => {
      const nodeId = 'test_node_123'
      const question = 'What is the meaning of life?'

      aiAssistant.handleAIQuery({ question, nodeId })

      expect(aiAssistant.activeQueries.has(nodeId)).toBe(true)
      expect(aiAssistant.activeQueries.get(nodeId).question).toBe(question)
    })

    it('should send query to LiveView', () => {
      const nodeId = 'test_node_456'
      const question = 'How do I test this?'

      aiAssistant.handleAIQuery({ question, nodeId })

      expect(mockPushEvent).toHaveBeenCalledWith('ai_query', {
        question,
        node_id: nodeId
      })
    })

    it('should cleanup query on completion', () => {
      const nodeId = 'test_node_789'

      aiAssistant.activeQueries.set(nodeId, {
        question: 'test',
        startTime: Date.now()
      })

      // Mock doc.descendants to simulate finding a node
      mockView.state.doc.descendants = vi.fn((callback) => {
        callback(
          { type: { name: 'ai_response' }, attrs: { nodeId } },
          5,
          { type: { name: 'paragraph' }, nodeSize: 10 },
          0
        )
      })

      aiAssistant.handleAIDone({ node_id: nodeId, response: 'Test response' })

      expect(aiAssistant.activeQueries.has(nodeId)).toBe(false)
    })

    it('should cancel active query', () => {
      const nodeId = 'cancel_test'

      aiAssistant.activeQueries.set(nodeId, {
        question: 'test',
        startTime: Date.now()
      })

      // Mock doc.descendants to prevent warnings
      mockView.state.doc.descendants = vi.fn()

      aiAssistant.cancelQuery(nodeId)

      expect(aiAssistant.activeQueries.has(nodeId)).toBe(false)
    })

    it('should cancel all active queries', () => {
      aiAssistant.activeQueries.set('query1', { question: 'q1', startTime: Date.now() })
      aiAssistant.activeQueries.set('query2', { question: 'q2', startTime: Date.now() })
      aiAssistant.activeQueries.set('query3', { question: 'q3', startTime: Date.now() })

      // Mock doc.descendants to prevent warnings
      mockView.state.doc.descendants = vi.fn()

      aiAssistant.cancelAllQueries()

      expect(aiAssistant.activeQueries.size).toBe(0)
    })
  })

  describe('Plugin creation', () => {
    it('should create AI mention plugin', () => {
      const plugin = aiAssistant.createPlugin()

      expect(plugin).toBeDefined()
      expect(plugin.spec).toBeDefined()
    })

    it('should pass correct callbacks to plugin', () => {
      const plugin = aiAssistant.createPlugin()

      // The plugin should have been created with the handleAIQuery callback
      // We verify this by checking that createPlugin doesn't throw
      expect(plugin).toBeDefined()
    })
  })

  describe('Query statistics', () => {
    it('should return active queries info', () => {
      aiAssistant.activeQueries.set('node1', { question: 'q1', startTime: Date.now() - 1000 })
      aiAssistant.activeQueries.set('node2', { question: 'q2', startTime: Date.now() - 500 })

      const info = aiAssistant.getActiveQueriesInfo()

      expect(info.count).toBe(2)
      expect(info.queries).toHaveLength(2)
      expect(info.queries[0].nodeId).toBeDefined()
      expect(info.queries[0].question).toBeDefined()
      expect(info.queries[0].duration).toBeGreaterThan(0)
    })
  })

  describe('Undo/Redo compatibility', () => {
    it('should not call stopCapturing on UndoManager', () => {
      // Regression test for undo/redo bug
      // The AI integration should NOT manipulate the UndoManager directly

      const nodeId = 'undo_test'
      const question = 'test question'

      // This should not throw or access ySyncPluginKey
      expect(() => {
        aiAssistant.handleAIQuery({ question, nodeId })
      }).not.toThrow()

      // Verify we didn't try to import ySyncPluginKey
      // (checking that the import was removed)
      const aiIntegrationSource = aiAssistant.constructor.toString()
      expect(aiIntegrationSource).not.toContain('stopCapturing')
    })

    it('should work with collaborative editing', () => {
      // The AI assistant should dispatch transactions normally,
      // allowing y-prosemirror to track them automatically

      const nodeId = 'collab_test'

      aiAssistant.activeQueries.set(nodeId, {
        question: 'test',
        startTime: Date.now()
      })

      // Mock doc.descendants
      mockView.state.doc.descendants = vi.fn((callback) => {
        callback(
          { type: { name: 'ai_response' }, attrs: { nodeId } },
          5,
          { type: { name: 'paragraph' }, nodeSize: 10 },
          0
        )
      })

      // This should dispatch transactions normally
      aiAssistant.handleAIDone({ node_id: nodeId, response: 'Test' })

      // Verify dispatch was called (y-prosemirror will handle undo tracking)
      expect(mockView.dispatch).toHaveBeenCalled()
    })
  })
})
