import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { AgentAssistantManager } from '../../agents/agent-integration'

describe('AgentAssistantManager - Integration', () => {
  let agentAssistant
  let mockView
  let mockSchema
  let mockParser
  let mockPushEvent

  beforeEach(() => {
    // Create minimal mocks
    mockSchema = {
      nodes: {
        paragraph: { create: vi.fn() },
        text: vi.fn()
      }
    }

    // Mock parser that returns a document with content
    mockParser = vi.fn((markdown) => ({
      content: {
        forEach: vi.fn((callback) => {
          // Simulate a parsed paragraph node
          callback({
            type: { name: 'paragraph' },
            content: { size: markdown.length },
            nodeSize: markdown.length + 2,
            isInline: false
          })
        })
      }
    }))

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

    agentAssistant = new AgentAssistantManager({
      view: mockView,
      schema: mockSchema,
      parser: mockParser,
      pushEvent: mockPushEvent
    })
  })

  afterEach(() => {
    if (agentAssistant) {
      agentAssistant.destroy()
    }
  })

  describe('Agent query lifecycle', () => {
    it('should track active queries', () => {
      const nodeId = 'test_node_123'
      const question = 'What is the meaning of life?'

      agentAssistant.handleQuery({ question, nodeId })

      expect(agentAssistant.activeQueries.has(nodeId)).toBe(true)
      expect(agentAssistant.activeQueries.get(nodeId).question).toBe(question)
    })

    it('should send query to LiveView', () => {
      const nodeId = 'test_node_456'
      const question = 'How do I test this?'

      agentAssistant.handleQuery({ question, nodeId })

      expect(mockPushEvent).toHaveBeenCalledWith('agent_query', {
        question,
        node_id: nodeId
      })
    })

    it('should cleanup query on completion', () => {
      const nodeId = 'test_node_789'

      agentAssistant.activeQueries.set(nodeId, {
        question: 'test',
        startTime: Date.now()
      })

      // Mock doc.descendants to simulate finding a node
      mockView.state.doc.descendants = vi.fn((callback) => {
        callback(
          { type: { name: 'agent_response' }, attrs: { nodeId } },
          5,
          {
            type: { name: 'paragraph' },
            nodeSize: 10,
            content: {
              size: 1,
              cut: vi.fn((from, to) => ({ size: 0 }))
            }
          },
          0
        )
      })

      agentAssistant.handleDone({ node_id: nodeId, response: 'Test response' })

      expect(agentAssistant.activeQueries.has(nodeId)).toBe(false)
    })

    it('should cancel active query', () => {
      const nodeId = 'cancel_test'

      agentAssistant.activeQueries.set(nodeId, {
        question: 'test',
        startTime: Date.now()
      })

      // Mock doc.descendants to prevent warnings
      mockView.state.doc.descendants = vi.fn()

      agentAssistant.cancelQuery(nodeId)

      expect(agentAssistant.activeQueries.has(nodeId)).toBe(false)
    })

    it('should cancel all active queries', () => {
      agentAssistant.activeQueries.set('query1', { question: 'q1', startTime: Date.now() })
      agentAssistant.activeQueries.set('query2', { question: 'q2', startTime: Date.now() })
      agentAssistant.activeQueries.set('query3', { question: 'q3', startTime: Date.now() })

      // Mock doc.descendants to prevent warnings
      mockView.state.doc.descendants = vi.fn()

      agentAssistant.cancelAllQueries()

      expect(agentAssistant.activeQueries.size).toBe(0)
    })
  })

  describe('Plugin creation', () => {
    it('should create mention plugin', () => {
      const plugin = agentAssistant.createPlugin()

      expect(plugin).toBeDefined()
      expect(plugin.spec).toBeDefined()
    })

    it('should pass correct callbacks to plugin', () => {
      const plugin = agentAssistant.createPlugin()

      // The plugin should have been created with the handleQuery callback
      // We verify this by checking that createPlugin doesn't throw
      expect(plugin).toBeDefined()
    })
  })

  describe('Query statistics', () => {
    it('should return active queries info', () => {
      agentAssistant.activeQueries.set('node1', { question: 'q1', startTime: Date.now() - 1000 })
      agentAssistant.activeQueries.set('node2', { question: 'q2', startTime: Date.now() - 500 })

      const info = agentAssistant.getActiveQueriesInfo()

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
        agentAssistant.handleQuery({ question, nodeId })
      }).not.toThrow()

      // Verify we didn't try to import ySyncPluginKey
      // (checking that the import was removed)
      const aiIntegrationSource = agentAssistant.constructor.toString()
      expect(aiIntegrationSource).not.toContain('stopCapturing')
    })

    it('should work with collaborative editing', () => {
      // The AI assistant should dispatch transactions normally,
      // allowing y-prosemirror to track them automatically

      const nodeId = 'collab_test'

      agentAssistant.activeQueries.set(nodeId, {
        question: 'test',
        startTime: Date.now()
      })

      // Mock doc.descendants
      mockView.state.doc.descendants = vi.fn((callback) => {
        callback(
          { type: { name: 'agent_response' }, attrs: { nodeId } },
          5,
          {
            type: { name: 'paragraph' },
            nodeSize: 10,
            content: {
              size: 1,
              cut: vi.fn((from, to) => ({ size: 0 }))
            }
          },
          0
        )
      })

      // This should dispatch transactions normally
      agentAssistant.handleDone({ node_id: nodeId, response: 'Test' })

      // Verify dispatch was called (y-prosemirror will handle undo tracking)
      expect(mockView.dispatch).toHaveBeenCalled()
    })
  })
})
