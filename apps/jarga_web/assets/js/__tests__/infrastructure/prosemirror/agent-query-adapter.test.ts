/**
 * AgentQueryAdapter Tests
 *
 * Tests for Map-based agent query storage adapter.
 */

import { describe, test, expect, beforeEach } from 'vitest'
import { AgentQueryAdapter } from '../../../infrastructure/prosemirror/agent-query-adapter'
import { AgentQuery } from '../../../domain/entities/agent-query'
import { QueryId } from '../../../domain/value-objects/query-id'
import { NodeId } from '../../../domain/value-objects/node-id'

describe('AgentQueryAdapter', () => {
  let adapter: AgentQueryAdapter

  beforeEach(() => {
    adapter = new AgentQueryAdapter()
  })

  describe('add', () => {
    test('adds a query to storage', () => {
      const query = AgentQuery.create('test question')

      adapter.add(query)

      expect(adapter.has(query.queryId)).toBe(true)
    })

    test('allows adding multiple queries', () => {
      const query1 = AgentQuery.create('question 1')
      const query2 = AgentQuery.create('question 2')

      adapter.add(query1)
      adapter.add(query2)

      expect(adapter.has(query1.queryId)).toBe(true)
      expect(adapter.has(query2.queryId)).toBe(true)
    })
  })

  describe('get', () => {
    test('returns query by query ID', () => {
      const query = AgentQuery.create('test question')
      adapter.add(query)

      const result = adapter.get(query.queryId)

      expect(result).toBe(query)
      expect(result?.question).toBe('test question')
    })

    test('returns undefined for non-existent query', () => {
      const queryId = QueryId.generate()

      const result = adapter.get(queryId)

      expect(result).toBeUndefined()
    })
  })

  describe('getByNodeId', () => {
    test('returns query by node ID', () => {
      const query = AgentQuery.create('test question')
      adapter.add(query)

      const result = adapter.getByNodeId(query.nodeId)

      expect(result).toBe(query)
      expect(result?.question).toBe('test question')
    })

    test('returns undefined for non-existent node ID', () => {
      const nodeId = NodeId.generate()

      const result = adapter.getByNodeId(nodeId)

      expect(result).toBeUndefined()
    })

    test('returns correct query when multiple queries exist', () => {
      const query1 = AgentQuery.create('question 1')
      const query2 = AgentQuery.create('question 2')
      adapter.add(query1)
      adapter.add(query2)

      const result = adapter.getByNodeId(query2.nodeId)

      expect(result).toBe(query2)
    })
  })

  describe('update', () => {
    test('updates existing query', () => {
      const query = AgentQuery.create('test question')
      adapter.add(query)

      const startedQuery = query.markAsStreaming()
      adapter.update(startedQuery)

      const result = adapter.get(query.queryId)
      expect(result?.status).toBe('streaming')
    })

    test('does nothing if query does not exist', () => {
      const query = AgentQuery.create('test question')

      // Should not throw
      expect(() => adapter.update(query)).not.toThrow()
    })
  })

  describe('remove', () => {
    test('removes query from storage', () => {
      const query = AgentQuery.create('test question')
      adapter.add(query)

      adapter.remove(query.queryId)

      expect(adapter.has(query.queryId)).toBe(false)
      expect(adapter.get(query.queryId)).toBeUndefined()
    })

    test('does nothing if query does not exist', () => {
      const queryId = QueryId.generate()

      // Should not throw
      expect(() => adapter.remove(queryId)).not.toThrow()
    })
  })

  describe('getActiveQueries', () => {
    test('returns empty array when no queries exist', () => {
      const result = adapter.getActiveQueries()

      expect(result).toEqual([])
    })

    test('returns all queries', () => {
      const query1 = AgentQuery.create('question 1')
      const query2 = AgentQuery.create('question 2')
      adapter.add(query1)
      adapter.add(query2)

      const result = adapter.getActiveQueries()

      expect(result).toHaveLength(2)
      expect(result).toContain(query1)
      expect(result).toContain(query2)
    })

    test('does not include removed queries', () => {
      const query1 = AgentQuery.create('question 1')
      const query2 = AgentQuery.create('question 2')
      adapter.add(query1)
      adapter.add(query2)
      adapter.remove(query1.queryId)

      const result = adapter.getActiveQueries()

      expect(result).toHaveLength(1)
      expect(result).toContain(query2)
      expect(result).not.toContain(query1)
    })
  })

  describe('has', () => {
    test('returns true for existing query', () => {
      const query = AgentQuery.create('test question')
      adapter.add(query)

      expect(adapter.has(query.queryId)).toBe(true)
    })

    test('returns false for non-existent query', () => {
      const queryId = QueryId.generate()

      expect(adapter.has(queryId)).toBe(false)
    })

    test('returns false after query is removed', () => {
      const query = AgentQuery.create('test question')
      adapter.add(query)
      adapter.remove(query.queryId)

      expect(adapter.has(query.queryId)).toBe(false)
    })
  })
})
