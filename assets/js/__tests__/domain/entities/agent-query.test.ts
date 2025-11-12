import { describe, test, expect } from 'vitest'
import { AgentQuery } from '../../../domain/entities/agent-query'
import { QueryId } from '../../../domain/value-objects/query-id'
import { NodeId } from '../../../domain/value-objects/node-id'

describe('AgentQuery', () => {
  describe('constructor', () => {
    test('creates agent query with valid parameters', () => {
      const queryId = new QueryId('query_123')
      const nodeId = new NodeId('agent_node_456')
      const question = 'What is TypeScript?'

      const query = new AgentQuery(queryId, nodeId, question)

      expect(query.queryId).toEqual(queryId)
      expect(query.nodeId).toEqual(nodeId)
      expect(query.question).toBe(question)
      expect(query.status).toBe('pending')
      expect(query.startTime).toBeInstanceOf(Date)
    })

    test('throws error for empty question', () => {
      const queryId = new QueryId('query_123')
      const nodeId = new NodeId('agent_node_456')

      expect(() => new AgentQuery(queryId, nodeId, '')).toThrow(
        'Question cannot be empty'
      )
    })

    test('throws error for whitespace-only question', () => {
      const queryId = new QueryId('query_123')
      const nodeId = new NodeId('agent_node_456')

      expect(() => new AgentQuery(queryId, nodeId, '   ')).toThrow(
        'Question cannot be empty'
      )
    })
  })

  describe('create', () => {
    test('creates agent query with generated IDs', () => {
      const query = AgentQuery.create('What is TypeScript?')

      expect(query.queryId).toBeInstanceOf(QueryId)
      expect(query.nodeId).toBeInstanceOf(NodeId)
      expect(query.question).toBe('What is TypeScript?')
      expect(query.status).toBe('pending')
    })

    test('generates unique IDs for each query', () => {
      const query1 = AgentQuery.create('Question 1')
      const query2 = AgentQuery.create('Question 2')

      expect(query1.queryId.equals(query2.queryId)).toBe(false)
      expect(query1.nodeId.equals(query2.nodeId)).toBe(false)
    })
  })

  describe('markAsStreaming', () => {
    test('transitions from pending to streaming', () => {
      const query = AgentQuery.create('What is TypeScript?')

      const updated = query.markAsStreaming()

      expect(updated.status).toBe('streaming')
      expect(updated.queryId).toEqual(query.queryId)
      expect(updated.question).toBe(query.question)
    })

    test('returns new instance (immutability)', () => {
      const query = AgentQuery.create('What is TypeScript?')

      const updated = query.markAsStreaming()

      expect(updated).not.toBe(query)
      expect(query.status).toBe('pending')
    })

    test('throws error when not pending', () => {
      const query = AgentQuery.create('What is TypeScript?')
      const streaming = query.markAsStreaming()

      expect(() => streaming.markAsStreaming()).toThrow(
        'Can only mark pending queries as streaming'
      )
    })
  })

  describe('markAsCompleted', () => {
    test('transitions from streaming to completed', () => {
      const query = AgentQuery.create('What is TypeScript?')
      const streaming = query.markAsStreaming()
      const response = 'TypeScript is a typed superset of JavaScript.'

      const completed = streaming.markAsCompleted(response)

      expect(completed.status).toBe('completed')
      expect(completed.response).toBe(response)
      expect(completed.endTime).toBeInstanceOf(Date)
    })

    test('returns new instance (immutability)', () => {
      const query = AgentQuery.create('What is TypeScript?')
      const streaming = query.markAsStreaming()

      const completed = streaming.markAsCompleted('response')

      expect(completed).not.toBe(streaming)
      expect(streaming.status).toBe('streaming')
      expect(streaming.response).toBeUndefined()
    })

    test('throws error when not streaming', () => {
      const query = AgentQuery.create('What is TypeScript?')

      expect(() => query.markAsCompleted('response')).toThrow(
        'Can only mark streaming queries as completed'
      )
    })

    test('throws error for empty response', () => {
      const query = AgentQuery.create('What is TypeScript?')
      const streaming = query.markAsStreaming()

      expect(() => streaming.markAsCompleted('')).toThrow(
        'Response cannot be empty'
      )
    })
  })

  describe('markAsFailed', () => {
    test('transitions from pending to failed', () => {
      const query = AgentQuery.create('What is TypeScript?')
      const error = 'Network error'

      const failed = query.markAsFailed(error)

      expect(failed.status).toBe('failed')
      expect(failed.error).toBe(error)
      expect(failed.endTime).toBeInstanceOf(Date)
    })

    test('transitions from streaming to failed', () => {
      const query = AgentQuery.create('What is TypeScript?')
      const streaming = query.markAsStreaming()
      const error = 'API error'

      const failed = streaming.markAsFailed(error)

      expect(failed.status).toBe('failed')
      expect(failed.error).toBe(error)
    })

    test('returns new instance (immutability)', () => {
      const query = AgentQuery.create('What is TypeScript?')

      const failed = query.markAsFailed('error')

      expect(failed).not.toBe(query)
      expect(query.status).toBe('pending')
      expect(query.error).toBeUndefined()
    })

    test('throws error for empty error message', () => {
      const query = AgentQuery.create('What is TypeScript?')

      expect(() => query.markAsFailed('')).toThrow('Error message cannot be empty')
    })
  })

  describe('getDuration', () => {
    test('returns null for pending query', () => {
      const query = AgentQuery.create('What is TypeScript?')

      expect(query.getDuration()).toBeNull()
    })

    test('returns null for streaming query without end time', () => {
      const query = AgentQuery.create('What is TypeScript?')
      const streaming = query.markAsStreaming()

      expect(streaming.getDuration()).toBeNull()
    })

    test('returns duration in milliseconds for completed query', () => {
      const query = AgentQuery.create('What is TypeScript?')
      const streaming = query.markAsStreaming()
      const completed = streaming.markAsCompleted('response')

      const duration = completed.getDuration()

      expect(duration).toBeGreaterThanOrEqual(0)
      expect(typeof duration).toBe('number')
    })

    test('returns duration in milliseconds for failed query', () => {
      const query = AgentQuery.create('What is TypeScript?')
      const failed = query.markAsFailed('error')

      const duration = failed.getDuration()

      expect(duration).toBeGreaterThanOrEqual(0)
      expect(typeof duration).toBe('number')
    })
  })

  describe('isActive', () => {
    test('returns true for pending query', () => {
      const query = AgentQuery.create('What is TypeScript?')

      expect(query.isActive()).toBe(true)
    })

    test('returns true for streaming query', () => {
      const query = AgentQuery.create('What is TypeScript?')
      const streaming = query.markAsStreaming()

      expect(streaming.isActive()).toBe(true)
    })

    test('returns false for completed query', () => {
      const query = AgentQuery.create('What is TypeScript?')
      const streaming = query.markAsStreaming()
      const completed = streaming.markAsCompleted('response')

      expect(completed.isActive()).toBe(false)
    })

    test('returns false for failed query', () => {
      const query = AgentQuery.create('What is TypeScript?')
      const failed = query.markAsFailed('error')

      expect(failed.isActive()).toBe(false)
    })
  })
})
