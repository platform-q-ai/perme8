/**
 * CancelAgentQuery Use Case Tests
 *
 * Tests for the CancelAgentQuery use case following TDD principles.
 * All dependencies are mocked to ensure fast, isolated tests.
 */

import { describe, test, expect, vi, beforeEach } from 'vitest'
import type { LiveViewBridge } from '../../../application/interfaces/liveview-bridge.interface'

// Import will fail initially (RED phase)
import { CancelAgentQuery } from '../../../application/use-cases/cancel-agent-query'

describe('CancelAgentQuery', () => {
  let mockBridge: LiveViewBridge
  let useCase: CancelAgentQuery

  beforeEach(() => {
    // Mock LiveViewBridge
    mockBridge = {
      pushEvent: vi.fn().mockResolvedValue(undefined),
      handleEvent: vi.fn()
    }

    // Create use case with mocked dependency
    useCase = new CancelAgentQuery(mockBridge)
  })

  describe('execute', () => {
    test('pushes cancel event to LiveView server', async () => {
      const queryId = 'query-123'

      await useCase.execute(queryId)

      expect(mockBridge.pushEvent).toHaveBeenCalledWith(
        'agent_cancel',
        { node_id: queryId }
      )
    })

    test('throws error if query ID is empty', async () => {
      await expect(useCase.execute('')).rejects.toThrow('Query ID cannot be empty')
    })

    test('throws error if query ID is whitespace only', async () => {
      await expect(useCase.execute('   ')).rejects.toThrow('Query ID cannot be empty')
    })

    test('handles multiple cancel requests independently', async () => {
      const queryId1 = 'query-1'
      const queryId2 = 'query-2'

      await useCase.execute(queryId1)
      await useCase.execute(queryId2)

      expect(mockBridge.pushEvent).toHaveBeenCalledTimes(2)
      expect(mockBridge.pushEvent).toHaveBeenNthCalledWith(
        1,
        'agent_cancel',
        { node_id: queryId1 }
      )
      expect(mockBridge.pushEvent).toHaveBeenNthCalledWith(
        2,
        'agent_cancel',
        { node_id: queryId2 }
      )
    })

    test('resolves successfully when bridge operation succeeds', async () => {
      const queryId = 'query-123'

      await expect(useCase.execute(queryId)).resolves.toBeUndefined()
    })

    test('propagates error when bridge operation fails', async () => {
      const queryId = 'query-123'
      const bridgeError = new Error('Network error')

      vi.mocked(mockBridge.pushEvent).mockRejectedValue(bridgeError)

      await expect(useCase.execute(queryId)).rejects.toThrow('Network error')
    })

    test('can cancel same query ID multiple times', async () => {
      const queryId = 'query-123'

      await useCase.execute(queryId)
      await useCase.execute(queryId)

      // Both cancellations should go through
      expect(mockBridge.pushEvent).toHaveBeenCalledTimes(2)
    })

    test('preserves query ID exactly as provided', async () => {
      const queryId = 'query-with-special-chars-123_ABC'

      await useCase.execute(queryId)

      expect(mockBridge.pushEvent).toHaveBeenCalledWith(
        'agent_cancel',
        { node_id: queryId }
      )
    })

    test('handles query IDs with various formats', async () => {
      const queryIds = [
        'query-123',
        'query_456',
        'QUERY-789',
        'query.abc.def',
        'query:timestamp:12345'
      ]

      for (const queryId of queryIds) {
        await useCase.execute(queryId)
      }

      expect(mockBridge.pushEvent).toHaveBeenCalledTimes(queryIds.length)
    })

    test('returns immediately without blocking', async () => {
      const queryId = 'query-123'

      const startTime = Date.now()
      await useCase.execute(queryId)
      const duration = Date.now() - startTime

      // Should be very fast (< 10ms)
      expect(duration).toBeLessThan(10)
    })

    test('does not modify query ID before sending', async () => {
      const originalQueryId = 'query-123-abc'

      await useCase.execute(originalQueryId)

      const callArgs = vi.mocked(mockBridge.pushEvent).mock.calls[0]
      expect(callArgs[1].node_id).toBe(originalQueryId)
    })
  })
})
