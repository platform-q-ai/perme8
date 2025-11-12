/**
 * Tests for UpdateCursorPosition use case
 *
 * Following TDD (RED-GREEN-REFACTOR):
 * - RED: These tests are written FIRST and will FAIL
 * - GREEN: Implementation will be written to make them pass
 * - REFACTOR: Code will be cleaned up while keeping tests green
 */

import { describe, test, expect, vi, beforeEach } from 'vitest'
import { UpdateCursorPosition } from '../../../application/use-cases/update-cursor-position'
import type { AwarenessAdapter } from '../../../application/interfaces/awareness-adapter.interface'
import { UserId } from '../../../domain/value-objects/user-id'

describe('UpdateCursorPosition', () => {
  let mockAwarenessAdapter: AwarenessAdapter
  let useCase: UpdateCursorPosition
  let userId: UserId

  beforeEach(() => {
    // Mock AwarenessAdapter
    mockAwarenessAdapter = {
      setLocalState: vi.fn(),
      onAwarenessChange: vi.fn(),
      encodeUpdate: vi.fn(),
      applyUpdate: vi.fn()
    }

    // Create use case with mocked dependency
    useCase = new UpdateCursorPosition(mockAwarenessAdapter)

    // Create test user ID
    userId = new UserId('user-789')
  })

  describe('execute', () => {
    test('updates awareness with cursor position', async () => {
      const position = 42

      await useCase.execute(userId, position)

      expect(mockAwarenessAdapter.setLocalState).toHaveBeenCalled()
    })

    test('includes user ID in awareness state', async () => {
      const position = 42

      await useCase.execute(userId, position)

      expect(mockAwarenessAdapter.setLocalState).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'user-789'
        })
      )
    })

    test('includes cursor position in awareness state', async () => {
      const position = 42

      await useCase.execute(userId, position)

      expect(mockAwarenessAdapter.setLocalState).toHaveBeenCalledWith(
        expect.objectContaining({
          cursor: 42
        })
      )
    })

    test('handles position at document start', async () => {
      await useCase.execute(userId, 0)

      expect(mockAwarenessAdapter.setLocalState).toHaveBeenCalledWith(
        expect.objectContaining({
          cursor: 0
        })
      )
    })

    test('handles large position values', async () => {
      await useCase.execute(userId, 999999)

      expect(mockAwarenessAdapter.setLocalState).toHaveBeenCalledWith(
        expect.objectContaining({
          cursor: 999999
        })
      )
    })

    test('updates cursor for different users', async () => {
      const userId1 = new UserId('user-1')
      const userId2 = new UserId('user-2')

      await useCase.execute(userId1, 10)
      await useCase.execute(userId2, 20)

      expect(mockAwarenessAdapter.setLocalState).toHaveBeenCalledTimes(2)
      expect(mockAwarenessAdapter.setLocalState).toHaveBeenNthCalledWith(
        1,
        expect.objectContaining({ userId: 'user-1', cursor: 10 })
      )
      expect(mockAwarenessAdapter.setLocalState).toHaveBeenNthCalledWith(
        2,
        expect.objectContaining({ userId: 'user-2', cursor: 20 })
      )
    })

    test('updates same cursor position multiple times', async () => {
      await useCase.execute(userId, 42)
      await useCase.execute(userId, 42)

      expect(mockAwarenessAdapter.setLocalState).toHaveBeenCalledTimes(2)
    })

    test('throws error for negative position', async () => {
      await expect(useCase.execute(userId, -1)).rejects.toThrow(
        'Cursor position must be non-negative'
      )
    })

    test('does not call adapter if position is invalid', async () => {
      try {
        await useCase.execute(userId, -1)
      } catch {
        // Expected error
      }

      expect(mockAwarenessAdapter.setLocalState).not.toHaveBeenCalled()
    })

    test('completes synchronously', async () => {
      const startTime = Date.now()

      await useCase.execute(userId, 42)

      const duration = Date.now() - startTime
      expect(duration).toBeLessThan(10) // Should be very fast
    })
  })
})
