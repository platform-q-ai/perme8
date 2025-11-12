/**
 * Tests for BroadcastAwareness use case
 *
 * Following TDD (RED-GREEN-REFACTOR):
 * - RED: These tests are written FIRST and will FAIL
 * - GREEN: Implementation will be written to make them pass
 * - REFACTOR: Code will be cleaned up while keeping tests green
 */

import { describe, test, expect, vi, beforeEach } from 'vitest'
import { BroadcastAwareness } from '../../../application/use-cases/broadcast-awareness'
import type { AwarenessAdapter } from '../../../application/interfaces/awareness-adapter.interface'
import type { LiveViewBridge } from '../../../application/interfaces/liveview-bridge.interface'
import { UserAwareness } from '../../../domain/entities/user-awareness'
import { UserId } from '../../../domain/value-objects/user-id'
import { UserName } from '../../../domain/value-objects/user-name'
import { UserColor } from '../../../domain/value-objects/user-color'
import { Selection } from '../../../domain/value-objects/selection'

describe('BroadcastAwareness', () => {
  let mockAwarenessAdapter: AwarenessAdapter
  let mockLiveViewBridge: LiveViewBridge
  let useCase: BroadcastAwareness
  let userAwareness: UserAwareness

  beforeEach(() => {
    // Mock AwarenessAdapter
    mockAwarenessAdapter = {
      setLocalState: vi.fn(),
      onAwarenessChange: vi.fn(),
      encodeUpdate: vi.fn().mockReturnValue(new Uint8Array([1, 2, 3, 4, 5])),
      applyUpdate: vi.fn()
    }

    // Mock LiveViewBridge
    mockLiveViewBridge = {
      pushEvent: vi.fn().mockResolvedValue(undefined),
      handleEvent: vi.fn()
    }

    // Create use case with mocked dependencies
    useCase = new BroadcastAwareness(mockAwarenessAdapter, mockLiveViewBridge)

    // Create test user awareness
    const userId = new UserId('user-123')
    const userName = new UserName('Alice')
    const userColor = new UserColor('#4ECDC4')
    userAwareness = UserAwareness.create(userId, userName, userColor)
  })

  describe('execute', () => {
    test('encodes awareness update from adapter', async () => {
      await useCase.execute(userAwareness)

      expect(mockAwarenessAdapter.encodeUpdate).toHaveBeenCalled()
    })

    test('passes client IDs to encode update', async () => {
      // The client ID should be extracted from the awareness system
      // For now, we'll encode updates for all clients (empty array means all)
      await useCase.execute(userAwareness)

      expect(mockAwarenessAdapter.encodeUpdate).toHaveBeenCalledWith([])
    })

    test('converts binary update to base64', async () => {
      const mockUpdate = new Uint8Array([1, 2, 3, 4, 5])
      vi.mocked(mockAwarenessAdapter.encodeUpdate).mockReturnValue(mockUpdate)

      await useCase.execute(userAwareness)

      const expectedBase64 = btoa(String.fromCharCode(1, 2, 3, 4, 5))
      expect(mockLiveViewBridge.pushEvent).toHaveBeenCalledWith(
        'awareness-update',
        expect.objectContaining({
          update: expectedBase64
        })
      )
    })

    test('broadcasts awareness via LiveView bridge', async () => {
      await useCase.execute(userAwareness)

      expect(mockLiveViewBridge.pushEvent).toHaveBeenCalledWith(
        'awareness-update',
        expect.any(Object)
      )
    })

    test('includes user ID in broadcast payload', async () => {
      await useCase.execute(userAwareness)

      expect(mockLiveViewBridge.pushEvent).toHaveBeenCalledWith(
        'awareness-update',
        expect.objectContaining({
          userId: 'user-123'
        })
      )
    })

    test('handles awareness with selection', async () => {
      const selection = new Selection(10, 20)
      const awarenessWithSelection = userAwareness.updateSelection(selection)

      await useCase.execute(awarenessWithSelection)

      expect(mockAwarenessAdapter.encodeUpdate).toHaveBeenCalled()
      expect(mockLiveViewBridge.pushEvent).toHaveBeenCalled()
    })

    test('handles awareness with cursor', async () => {
      const awarenessWithCursor = userAwareness.updateCursor(42)

      await useCase.execute(awarenessWithCursor)

      expect(mockAwarenessAdapter.encodeUpdate).toHaveBeenCalled()
      expect(mockLiveViewBridge.pushEvent).toHaveBeenCalled()
    })

    test('handles empty awareness update', async () => {
      vi.mocked(mockAwarenessAdapter.encodeUpdate).mockReturnValue(new Uint8Array([]))

      await useCase.execute(userAwareness)

      expect(mockLiveViewBridge.pushEvent).toHaveBeenCalledWith(
        'awareness-update',
        expect.objectContaining({
          update: ''
        })
      )
    })

    test('awaits LiveView broadcast before completing', async () => {
      let pushEventResolved = false
      vi.mocked(mockLiveViewBridge.pushEvent).mockImplementation(async () => {
        await new Promise(resolve => setTimeout(resolve, 10))
        pushEventResolved = true
      })

      await useCase.execute(userAwareness)

      expect(pushEventResolved).toBe(true)
    })

    test('throws error if encoding fails', async () => {
      vi.mocked(mockAwarenessAdapter.encodeUpdate).mockImplementation(() => {
        throw new Error('Encoding failed')
      })

      await expect(useCase.execute(userAwareness)).rejects.toThrow('Encoding failed')
    })

    test('throws error if broadcast fails', async () => {
      vi.mocked(mockLiveViewBridge.pushEvent).mockRejectedValue(
        new Error('Network error')
      )

      await expect(useCase.execute(userAwareness)).rejects.toThrow('Network error')
    })
  })
})
