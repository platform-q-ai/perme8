import { describe, test, expect } from 'vitest'
import { AgentResponse } from '../../../domain/entities/agent-response'
import { NodeId } from '../../../domain/value-objects/node-id'

describe('AgentResponse', () => {
  describe('constructor', () => {
    test('creates agent response with valid parameters', () => {
      const nodeId = new NodeId('agent_node_123')

      const response = new AgentResponse(nodeId, 'streaming', 'Hello', '')

      expect(response.nodeId).toEqual(nodeId)
      expect(response.state).toBe('streaming')
      expect(response.content).toBe('Hello')
      expect(response.error).toBe('')
    })

    test('creates agent response with default empty content', () => {
      const nodeId = new NodeId('agent_node_123')

      const response = new AgentResponse(nodeId, 'streaming')

      expect(response.content).toBe('')
      expect(response.error).toBe('')
    })
  })

  describe('create', () => {
    test('creates initial streaming response', () => {
      const nodeId = new NodeId('agent_node_123')

      const response = AgentResponse.create(nodeId)

      expect(response.nodeId).toEqual(nodeId)
      expect(response.state).toBe('streaming')
      expect(response.content).toBe('')
      expect(response.error).toBe('')
    })
  })

  describe('appendChunk', () => {
    test('appends chunk to empty content', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = AgentResponse.create(nodeId)

      const updated = response.appendChunk('Hello')

      expect(updated.content).toBe('Hello')
      expect(updated.state).toBe('streaming')
    })

    test('appends chunk to existing content', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = new AgentResponse(nodeId, 'streaming', 'Hello')

      const updated = response.appendChunk(' World')

      expect(updated.content).toBe('Hello World')
    })

    test('returns new instance (immutability)', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = AgentResponse.create(nodeId)

      const updated = response.appendChunk('Hello')

      expect(updated).not.toBe(response)
      expect(response.content).toBe('')
    })

    test('throws error when not streaming', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = new AgentResponse(nodeId, 'error', '', 'Failed')

      expect(() => response.appendChunk('chunk')).toThrow(
        'Can only append chunks to streaming responses'
      )
    })
  })

  describe('markAsError', () => {
    test('marks streaming response as error', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = AgentResponse.create(nodeId)

      const failed = response.markAsError('Network error')

      expect(failed.state).toBe('error')
      expect(failed.error).toBe('Network error')
      expect(failed.content).toBe('')
    })

    test('clears content when marked as error', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = new AgentResponse(nodeId, 'streaming', 'Some content')

      const failed = response.markAsError('API error')

      expect(failed.content).toBe('')
      expect(failed.error).toBe('API error')
    })

    test('returns new instance (immutability)', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = AgentResponse.create(nodeId)

      const failed = response.markAsError('error')

      expect(failed).not.toBe(response)
      expect(response.state).toBe('streaming')
      expect(response.error).toBe('')
    })

    test('throws error for empty error message', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = AgentResponse.create(nodeId)

      expect(() => response.markAsError('')).toThrow('Error message cannot be empty')
    })

    test('throws error for whitespace-only error message', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = AgentResponse.create(nodeId)

      expect(() => response.markAsError('   ')).toThrow('Error message cannot be empty')
    })
  })

  describe('updateAttributes', () => {
    test('updates state only', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = AgentResponse.create(nodeId)

      const updated = response.updateAttributes({ state: 'error' })

      expect(updated.state).toBe('error')
      expect(updated.content).toBe(response.content)
    })

    test('updates content only', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = AgentResponse.create(nodeId)

      const updated = response.updateAttributes({ content: 'New content' })

      expect(updated.content).toBe('New content')
      expect(updated.state).toBe(response.state)
    })

    test('updates multiple attributes', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = AgentResponse.create(nodeId)

      const updated = response.updateAttributes({
        state: 'error',
        content: '',
        error: 'Failed'
      })

      expect(updated.state).toBe('error')
      expect(updated.content).toBe('')
      expect(updated.error).toBe('Failed')
    })

    test('returns new instance (immutability)', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = AgentResponse.create(nodeId)

      const updated = response.updateAttributes({ content: 'test' })

      expect(updated).not.toBe(response)
      expect(response.content).toBe('')
    })
  })

  describe('isStreaming', () => {
    test('returns true when state is streaming', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = AgentResponse.create(nodeId)

      expect(response.isStreaming()).toBe(true)
    })

    test('returns false when state is error', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = new AgentResponse(nodeId, 'error', '', 'Failed')

      expect(response.isStreaming()).toBe(false)
    })
  })

  describe('hasError', () => {
    test('returns false for streaming response', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = AgentResponse.create(nodeId)

      expect(response.hasError()).toBe(false)
    })

    test('returns true for error response', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = new AgentResponse(nodeId, 'error', '', 'Failed')

      expect(response.hasError()).toBe(true)
    })
  })

  describe('hasContent', () => {
    test('returns false for empty content', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = AgentResponse.create(nodeId)

      expect(response.hasContent()).toBe(false)
    })

    test('returns false for whitespace-only content', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = new AgentResponse(nodeId, 'streaming', '   ')

      expect(response.hasContent()).toBe(false)
    })

    test('returns true for non-empty content', () => {
      const nodeId = new NodeId('agent_node_123')
      const response = new AgentResponse(nodeId, 'streaming', 'Hello')

      expect(response.hasContent()).toBe(true)
    })
  })
})
