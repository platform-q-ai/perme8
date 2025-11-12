import { describe, test, expect, vi, beforeEach } from 'vitest'
import { TriggerAgentQuery } from '../../../application/use-cases/trigger-agent-query'
import { AgentQuery } from '../../../domain/entities/agent-query'
import { MentionDetection } from '../../../domain/policies/mention-detection-policy'
import type { IAgentQueryAdapter } from '../../../application/interfaces/agent-query-adapter'
import type { IAgentNodeAdapter } from '../../../application/interfaces/agent-node-adapter'
import type { ILiveViewEventAdapter } from '../../../application/interfaces/liveview-event-adapter'

describe('TriggerAgentQuery', () => {
  let mockQueryAdapter: IAgentQueryAdapter
  let mockNodeAdapter: IAgentNodeAdapter
  let mockEventAdapter: ILiveViewEventAdapter
  let useCase: TriggerAgentQuery

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

    mockEventAdapter = {
      pushEvent: vi.fn(),
      handleEvent: vi.fn()
    }

    useCase = new TriggerAgentQuery(
      mockQueryAdapter,
      mockNodeAdapter,
      mockEventAdapter
    )
  })

  describe('execute', () => {
    test('creates query and node, then pushes event', () => {
      const mention: MentionDetection = {
        from: 0,
        to: 22,
        text: '@j what is TypeScript?'
      }
      const question = 'what is TypeScript?'

      const query = useCase.execute(mention, question)

      // Verify query was created
      expect(query).toBeInstanceOf(AgentQuery)
      expect(query.question).toBe(question)
      expect(query.status).toBe('pending')

      // Verify query was added to adapter
      expect(mockQueryAdapter.add).toHaveBeenCalledWith(query)

      // Verify node was created and inserted
      expect(mockNodeAdapter.createAndInsert).toHaveBeenCalledWith(
        mention,
        query.nodeId
      )

      // Verify event was pushed to LiveView
      expect(mockEventAdapter.pushEvent).toHaveBeenCalledWith('agent_query', {
        question,
        node_id: query.nodeId.value
      })
    })

    test('returns created query', () => {
      const mention: MentionDetection = {
        from: 0,
        to: 22,
        text: '@j what is TypeScript?'
      }
      const question = 'what is TypeScript?'

      const query = useCase.execute(mention, question)

      expect(query.queryId).toBeDefined()
      expect(query.nodeId).toBeDefined()
      expect(query.question).toBe(question)
    })

    test('throws error for empty question', () => {
      const mention: MentionDetection = {
        from: 0,
        to: 3,
        text: '@j '
      }

      expect(() => useCase.execute(mention, '')).toThrow('Question cannot be empty')
    })
  })
})
