import { describe, test, expect, vi, beforeEach } from 'vitest'
import { HandleAgentChunk } from '../../../application/use-cases/handle-agent-chunk'
import { NodeId } from '../../../domain/value-objects/node-id'
import { AgentQuery } from '../../../domain/entities/agent-query'
import type { IAgentNodeAdapter } from '../../../application/interfaces/agent-node-adapter'
import type { IAgentQueryAdapter } from '../../../application/interfaces/agent-query-adapter'

describe('HandleAgentChunk', () => {
  let mockNodeAdapter: IAgentNodeAdapter
  let mockQueryAdapter: IAgentQueryAdapter
  let useCase: HandleAgentChunk

  beforeEach(() => {
    mockNodeAdapter = {
      createAndInsert: vi.fn(),
      update: vi.fn(),
      appendChunk: vi.fn(),
      replaceWithMarkdown: vi.fn(),
      exists: vi.fn()
    }

    mockQueryAdapter = {
      add: vi.fn(),
      get: vi.fn(),
      getByNodeId: vi.fn(),
      update: vi.fn(),
      remove: vi.fn(),
      getActiveQueries: vi.fn(),
      has: vi.fn()
    }

    useCase = new HandleAgentChunk(mockNodeAdapter, mockQueryAdapter)
  })

  describe('execute', () => {
    test('appends chunk to node', () => {
      const nodeIdValue = 'agent_node_123'
      const chunk = 'Hello'

      vi.mocked(mockQueryAdapter.getByNodeId).mockReturnValue(undefined)

      useCase.execute({ nodeId: nodeIdValue, chunk })

      expect(mockNodeAdapter.appendChunk).toHaveBeenCalledWith(
        expect.objectContaining({ value: nodeIdValue }),
        chunk
      )
    })

    test('marks pending query as streaming on first chunk', () => {
      const nodeIdValue = 'agent_node_123'
      const chunk = 'Hello'

      const query = AgentQuery.create('What is TypeScript?')
      vi.mocked(mockQueryAdapter.getByNodeId).mockReturnValue(query)

      useCase.execute({ nodeId: nodeIdValue, chunk })

      // Verify query was marked as streaming
      expect(mockQueryAdapter.update).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 'streaming'
        })
      )

      // Verify chunk was still appended
      expect(mockNodeAdapter.appendChunk).toHaveBeenCalledWith(
        expect.objectContaining({ value: nodeIdValue }),
        chunk
      )
    })

    test('does not mark already streaming query as streaming', () => {
      const nodeIdValue = 'agent_node_123'
      const chunk = 'World'

      const query = AgentQuery.create('What is TypeScript?')
      const streaming = query.markAsStreaming()
      vi.mocked(mockQueryAdapter.getByNodeId).mockReturnValue(streaming)

      useCase.execute({ nodeId: nodeIdValue, chunk })

      // Should not update query state
      expect(mockQueryAdapter.update).not.toHaveBeenCalled()

      // But should still append chunk
      expect(mockNodeAdapter.appendChunk).toHaveBeenCalledWith(
        expect.objectContaining({ value: nodeIdValue }),
        chunk
      )
    })

    test('does not mark completed query as streaming', () => {
      const nodeIdValue = 'agent_node_123'
      const chunk = 'Extra'

      const query = AgentQuery.create('What is TypeScript?')
      const streaming = query.markAsStreaming()
      const completed = streaming.markAsCompleted('Answer')
      vi.mocked(mockQueryAdapter.getByNodeId).mockReturnValue(completed)

      useCase.execute({ nodeId: nodeIdValue, chunk })

      // Should not update query state
      expect(mockQueryAdapter.update).not.toHaveBeenCalled()

      // But should still append chunk
      expect(mockNodeAdapter.appendChunk).toHaveBeenCalledWith(
        expect.objectContaining({ value: nodeIdValue }),
        chunk
      )
    })

    test('handles chunk when query is not found', () => {
      const nodeIdValue = 'agent_node_123'
      const chunk = 'Hello'

      vi.mocked(mockQueryAdapter.getByNodeId).mockReturnValue(undefined)

      useCase.execute({ nodeId: nodeIdValue, chunk })

      // Should not attempt to update query
      expect(mockQueryAdapter.update).not.toHaveBeenCalled()

      // But should still append chunk
      expect(mockNodeAdapter.appendChunk).toHaveBeenCalledWith(
        expect.objectContaining({ value: nodeIdValue }),
        chunk
      )
    })

    test('handles multiple chunks correctly', () => {
      const nodeIdValue = 'agent_node_123'

      const query = AgentQuery.create('What is TypeScript?')
      vi.mocked(mockQueryAdapter.getByNodeId).mockReturnValueOnce(query)

      const streaming = query.markAsStreaming()
      vi.mocked(mockQueryAdapter.getByNodeId).mockReturnValueOnce(streaming)
      vi.mocked(mockQueryAdapter.getByNodeId).mockReturnValueOnce(streaming)

      // First chunk - should mark as streaming
      useCase.execute({ nodeId: nodeIdValue, chunk: 'Hello' })
      expect(mockQueryAdapter.update).toHaveBeenCalledTimes(1)

      // Second and third chunks - should not mark as streaming
      useCase.execute({ nodeId: nodeIdValue, chunk: ' ' })
      useCase.execute({ nodeId: nodeIdValue, chunk: 'World' })
      expect(mockQueryAdapter.update).toHaveBeenCalledTimes(1)

      // All chunks should be appended
      expect(mockNodeAdapter.appendChunk).toHaveBeenCalledTimes(3)
    })

    test('passes node ID as NodeId value object', () => {
      const nodeIdValue = 'agent_node_123'
      const chunk = 'test'

      vi.mocked(mockQueryAdapter.getByNodeId).mockReturnValue(undefined)

      useCase.execute({ nodeId: nodeIdValue, chunk })

      const [nodeId, _chunk] = vi.mocked(mockNodeAdapter.appendChunk).mock.calls[0]
      expect(nodeId).toBeInstanceOf(NodeId)
      expect(nodeId.value).toBe(nodeIdValue)
    })
  })
})
