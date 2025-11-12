import { describe, test, expect, vi, beforeEach } from 'vitest'
import { HandleAgentError } from '../../../application/use-cases/handle-agent-error'
import { AgentQuery } from '../../../domain/entities/agent-query'
import { AgentResponse } from '../../../domain/entities/agent-response'
import type { IAgentQueryAdapter } from '../../../application/interfaces/agent-query-adapter'
import type { IAgentNodeAdapter } from '../../../application/interfaces/agent-node-adapter'

describe('HandleAgentError', () => {
  let mockQueryAdapter: IAgentQueryAdapter
  let mockNodeAdapter: IAgentNodeAdapter
  let useCase: HandleAgentError

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

    useCase = new HandleAgentError(mockQueryAdapter, mockNodeAdapter)
  })

  describe('execute', () => {
    test('updates node to error state and marks query as failed', () => {
      const nodeIdValue = 'agent_node_123'
      const error = 'Network error'

      const query = AgentQuery.create('What is TypeScript?')
      const streaming = query.markAsStreaming()

      vi.mocked(mockQueryAdapter.getByNodeId).mockReturnValue(streaming)

      useCase.execute({ nodeId: nodeIdValue, error })

      // Verify node was updated to error state
      expect(mockNodeAdapter.update).toHaveBeenCalledWith(
        expect.objectContaining({
          nodeId: expect.objectContaining({ value: nodeIdValue }),
          state: 'error',
          error
        })
      )

      // Verify query was marked as failed
      expect(mockQueryAdapter.update).toHaveBeenCalledWith(
        expect.objectContaining({
          status: 'failed',
          error
        })
      )
    })

    test('does nothing if query not found', () => {
      vi.mocked(mockQueryAdapter.getByNodeId).mockReturnValue(undefined)

      useCase.execute({ nodeId: 'agent_node_123', error: 'error' })

      expect(mockNodeAdapter.update).not.toHaveBeenCalled()
      expect(mockQueryAdapter.update).not.toHaveBeenCalled()
    })

    test('passes AgentResponse entity to node adapter', () => {
      const nodeIdValue = 'agent_node_123'
      const error = 'test error'

      const query = AgentQuery.create('question')
      vi.mocked(mockQueryAdapter.getByNodeId).mockReturnValue(query)

      useCase.execute({ nodeId: nodeIdValue, error })

      const [response] = vi.mocked(mockNodeAdapter.update).mock.calls[0]
      expect(response).toBeInstanceOf(AgentResponse)
      expect(response.state).toBe('error')
      expect(response.error).toBe(error)
    })
  })
})
