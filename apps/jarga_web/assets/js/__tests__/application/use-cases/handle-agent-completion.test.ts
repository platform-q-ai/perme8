import { describe, test, expect, vi, beforeEach } from 'vitest'
import { HandleAgentCompletion } from '../../../application/use-cases/handle-agent-completion'
import { AgentQuery } from '../../../domain/entities/agent-query'
import { NodeId } from '../../../domain/value-objects/node-id'
import type { IAgentQueryAdapter } from '../../../application/interfaces/agent-query-adapter'
import type { IAgentNodeAdapter } from '../../../application/interfaces/agent-node-adapter'

describe('HandleAgentCompletion', () => {
  let mockQueryAdapter: IAgentQueryAdapter
  let mockNodeAdapter: IAgentNodeAdapter
  let useCase: HandleAgentCompletion

  beforeEach(() => {
    mockQueryAdapter = {
      add: vi.fn(),
      get: vi.fn(),
      getByNodeId: vi.fn(),
      update: vi.fn(),
      remove: vi.fn(),
      getActiveQueries: vi.fn(),
      has: vi.fn()
    }

    mockNodeAdapter = {
      createAndInsert: vi.fn(),
      update: vi.fn(),
      appendChunk: vi.fn(),
      replaceWithMarkdown: vi.fn(),
      exists: vi.fn()
    }

    useCase = new HandleAgentCompletion(mockQueryAdapter, mockNodeAdapter)
  })

  describe('execute', () => {
    test('replaces node with markdown and updates query', () => {
      const nodeIdValue = 'agent_node_123'
      const response = 'TypeScript is a typed superset of JavaScript.'

      const query = AgentQuery.create('What is TypeScript?')
      const streaming = query.markAsStreaming()

      vi.mocked(mockQueryAdapter.getByNodeId).mockReturnValue(streaming)

      useCase.execute({ nodeId: nodeIdValue, response })

      // Verify node was replaced with markdown
      expect(mockNodeAdapter.replaceWithMarkdown).toHaveBeenCalledWith(
        expect.objectContaining({ value: nodeIdValue }),
        response
      )

      // Verify query was marked as completed
      expect(mockQueryAdapter.update).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 'completed',
          response
        })
      )
    })

    test('does nothing if query not found', () => {
      vi.mocked(mockQueryAdapter.getByNodeId).mockReturnValue(undefined)

      useCase.execute({ nodeId: 'agent_node_123', response: 'response' })

      expect(mockNodeAdapter.replaceWithMarkdown).not.toHaveBeenCalled()
      expect(mockQueryAdapter.update).not.toHaveBeenCalled()
    })

    test('passes node ID as NodeId value object', () => {
      const nodeIdValue = 'agent_node_123'
      const response = 'test'

      const query = AgentQuery.create('question')
      const streaming = query.markAsStreaming()
      vi.mocked(mockQueryAdapter.getByNodeId).mockReturnValue(streaming)

      useCase.execute({ nodeId: nodeIdValue, response })

      const [nodeId, _response] = vi.mocked(mockNodeAdapter.replaceWithMarkdown).mock.calls[0]
      expect(nodeId).toBeInstanceOf(NodeId)
      expect(nodeId.value).toBe(nodeIdValue)
    })
  })
})
