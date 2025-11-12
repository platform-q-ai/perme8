import { describe, test, expect } from 'vitest'
import { NodeId } from '../../../domain/value-objects/node-id'

describe('NodeId', () => {
  describe('constructor', () => {
    test('creates node id with valid string', () => {
      const nodeId = new NodeId('agent_node_123')

      expect(nodeId.value).toBe('agent_node_123')
    })

    test('throws error for empty string', () => {
      expect(() => new NodeId('')).toThrow('Node ID cannot be empty')
    })

    test('throws error for whitespace-only string', () => {
      expect(() => new NodeId('   ')).toThrow('Node ID cannot be empty')
    })
  })

  describe('generate', () => {
    test('generates unique node id', () => {
      const nodeId1 = NodeId.generate()
      const nodeId2 = NodeId.generate()

      expect(nodeId1.value).not.toBe(nodeId2.value)
    })

    test('generated id starts with agent_node_ prefix', () => {
      const nodeId = NodeId.generate()

      expect(nodeId.value).toMatch(/^agent_node_/)
    })

    test('generated id contains timestamp', () => {
      const beforeTimestamp = Date.now()
      const nodeId = NodeId.generate()
      const afterTimestamp = Date.now()

      // Extract timestamp from generated ID (format: agent_node_{timestamp}_{random})
      const parts = nodeId.value.split('_')
      const timestamp = parseInt(parts[2])

      expect(timestamp).toBeGreaterThanOrEqual(beforeTimestamp)
      expect(timestamp).toBeLessThanOrEqual(afterTimestamp)
    })

    test('generated id contains random suffix', () => {
      const nodeId = NodeId.generate()

      // Should have format: agent_node_{timestamp}_{random}
      const parts = nodeId.value.split('_')
      expect(parts.length).toBeGreaterThan(3)
      expect(parts[parts.length - 1]).toMatch(/^[a-z0-9]+$/)
    })
  })

  describe('equals', () => {
    test('returns true for same id value', () => {
      const nodeId1 = new NodeId('agent_node_123')
      const nodeId2 = new NodeId('agent_node_123')

      expect(nodeId1.equals(nodeId2)).toBe(true)
    })

    test('returns false for different id values', () => {
      const nodeId1 = new NodeId('agent_node_123')
      const nodeId2 = new NodeId('agent_node_456')

      expect(nodeId1.equals(nodeId2)).toBe(false)
    })
  })

  describe('toString', () => {
    test('returns string representation', () => {
      const nodeId = new NodeId('agent_node_123')

      expect(nodeId.toString()).toBe('agent_node_123')
    })
  })
})
