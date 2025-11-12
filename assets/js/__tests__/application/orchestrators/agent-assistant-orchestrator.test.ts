import { describe, test, expect, vi, beforeEach } from 'vitest'
import { AgentAssistantOrchestrator } from '../../../application/orchestrators/agent-assistant-orchestrator'
import { DetectAgentMention } from '../../../application/use-cases/detect-agent-mention'
import { TriggerAgentQuery } from '../../../application/use-cases/trigger-agent-query'
import { HandleAgentChunk } from '../../../application/use-cases/handle-agent-chunk'
import { HandleAgentCompletion } from '../../../application/use-cases/handle-agent-completion'
import { HandleAgentError } from '../../../application/use-cases/handle-agent-error'

describe('AgentAssistantOrchestrator', () => {
  let mockDetectMention: DetectAgentMention
  let mockTriggerQuery: TriggerAgentQuery
  let mockHandleChunk: HandleAgentChunk
  let mockHandleCompletion: HandleAgentCompletion
  let mockHandleError: HandleAgentError
  let orchestrator: AgentAssistantOrchestrator

  beforeEach(() => {
    mockDetectMention = {
      execute: vi.fn(),
      hasValidMention: vi.fn(),
      extractQuestion: vi.fn()
    } as any

    mockTriggerQuery = {
      execute: vi.fn()
    } as any

    mockHandleChunk = {
      execute: vi.fn()
    } as any

    mockHandleCompletion = {
      execute: vi.fn()
    } as any

    mockHandleError = {
      execute: vi.fn()
    } as any

    orchestrator = new AgentAssistantOrchestrator(
      mockDetectMention,
      mockTriggerQuery,
      mockHandleChunk,
      mockHandleCompletion,
      mockHandleError
    )
  })

  describe('onEnterKey', () => {
    test('triggers query when valid mention found', () => {
      const detection = { from: 0, to: 22, text: '@j what is TypeScript?' }
      const question = 'what is TypeScript?'

      vi.mocked(mockDetectMention.execute).mockReturnValue(detection)
      vi.mocked(mockDetectMention.extractQuestion).mockReturnValue(question)

      const result = orchestrator.onEnterKey()

      expect(result).toBe(true)
      expect(mockTriggerQuery.execute).toHaveBeenCalledWith(detection, question)
    })

    test('returns false when no mention found', () => {
      vi.mocked(mockDetectMention.execute).mockReturnValue(null)

      const result = orchestrator.onEnterKey()

      expect(result).toBe(false)
      expect(mockTriggerQuery.execute).not.toHaveBeenCalled()
    })

    test('returns false when question extraction fails', () => {
      const detection = { from: 0, to: 3, text: '@j ' }

      vi.mocked(mockDetectMention.execute).mockReturnValue(detection)
      vi.mocked(mockDetectMention.extractQuestion).mockReturnValue(null)

      const result = orchestrator.onEnterKey()

      expect(result).toBe(false)
      expect(mockTriggerQuery.execute).not.toHaveBeenCalled()
    })
  })

  describe('onChunk', () => {
    test('handles chunk event', () => {
      const payload = { node_id: 'agent_node_123', chunk: 'Hello' }

      orchestrator.onChunk(payload)

      expect(mockHandleChunk.execute).toHaveBeenCalledWith({
        nodeId: 'agent_node_123',
        chunk: 'Hello'
      })
    })

    test('handles multiple chunks', () => {
      orchestrator.onChunk({ node_id: 'agent_node_123', chunk: 'Hello' })
      orchestrator.onChunk({ node_id: 'agent_node_123', chunk: ' World' })

      expect(mockHandleChunk.execute).toHaveBeenCalledTimes(2)
    })
  })

  describe('onDone', () => {
    test('handles completion event', () => {
      const payload = {
        node_id: 'agent_node_123',
        response: 'TypeScript is a typed superset of JavaScript.'
      }

      orchestrator.onDone(payload)

      expect(mockHandleCompletion.execute).toHaveBeenCalledWith({
        nodeId: 'agent_node_123',
        response: 'TypeScript is a typed superset of JavaScript.'
      })
    })
  })

  describe('onError', () => {
    test('handles error event', () => {
      const payload = { node_id: 'agent_node_123', error: 'Network error' }

      orchestrator.onError(payload)

      expect(mockHandleError.execute).toHaveBeenCalledWith({
        nodeId: 'agent_node_123',
        error: 'Network error'
      })
    })

    test('uses default error message if not provided', () => {
      const payload = { node_id: 'agent_node_123' }

      orchestrator.onError(payload)

      expect(mockHandleError.execute).toHaveBeenCalledWith({
        nodeId: 'agent_node_123',
        error: 'An unknown error occurred'
      })
    })
  })
})
