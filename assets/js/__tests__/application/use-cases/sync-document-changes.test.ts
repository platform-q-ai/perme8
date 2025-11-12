/**
 * Tests for SyncDocumentChanges use case
 *
 * Following TDD: Write tests FIRST, then implement.
 * Tests use mocked dependencies (DocumentAdapter, LiveViewBridge).
 *
 * @module __tests__/application/use-cases
 */

import { describe, test, expect, vi, beforeEach } from 'vitest'
import { SyncDocumentChanges } from '../../../application/use-cases/sync-document-changes'
import type { DocumentAdapter } from '../../../application/interfaces/document-adapter.interface'
import type { LiveViewBridge } from '../../../application/interfaces/liveview-bridge.interface'

describe('SyncDocumentChanges', () => {
  let mockDocumentAdapter: DocumentAdapter
  let mockLiveViewBridge: LiveViewBridge
  let useCase: SyncDocumentChanges

  beforeEach(() => {
    // Create mock DocumentAdapter
    mockDocumentAdapter = {
      applyUpdate: vi.fn(),
      getCurrentState: vi.fn(),
      onUpdate: vi.fn()
    }

    // Create mock LiveViewBridge
    mockLiveViewBridge = {
      pushEvent: vi.fn(),
      handleEvent: vi.fn()
    }

    // Create use case with mocked dependencies
    useCase = new SyncDocumentChanges(mockDocumentAdapter, mockLiveViewBridge)
  })

  describe('execute', () => {
    test('gets current state from adapter', async () => {
      const mockState = new Uint8Array([1, 2, 3])
      vi.mocked(mockDocumentAdapter.getCurrentState).mockResolvedValue(mockState)
      vi.mocked(mockLiveViewBridge.pushEvent).mockResolvedValue()

      await useCase.execute()

      expect(mockDocumentAdapter.getCurrentState).toHaveBeenCalledOnce()
    })

    test('encodes state as base64', async () => {
      const mockState = new Uint8Array([72, 101, 108, 108, 111]) // "Hello"
      vi.mocked(mockDocumentAdapter.getCurrentState).mockResolvedValue(mockState)
      vi.mocked(mockLiveViewBridge.pushEvent).mockResolvedValue()

      await useCase.execute()

      // Verify pushEvent was called with base64-encoded data
      expect(mockLiveViewBridge.pushEvent).toHaveBeenCalledWith(
        'sync-document',
        expect.objectContaining({
          update: expect.any(String)
        })
      )
    })

    test('pushes sync event to LiveView with encoded update', async () => {
      const mockState = new Uint8Array([1, 2, 3])
      const expectedBase64 = btoa(String.fromCharCode(...mockState))
      vi.mocked(mockDocumentAdapter.getCurrentState).mockResolvedValue(mockState)
      vi.mocked(mockLiveViewBridge.pushEvent).mockResolvedValue()

      await useCase.execute()

      expect(mockLiveViewBridge.pushEvent).toHaveBeenCalledWith(
        'sync-document',
        { update: expectedBase64 }
      )
    })

    test('throws error when adapter fails to get state', async () => {
      const error = new Error('Failed to get state')
      vi.mocked(mockDocumentAdapter.getCurrentState).mockRejectedValue(error)

      await expect(useCase.execute()).rejects.toThrow('Failed to get state')
      expect(mockLiveViewBridge.pushEvent).not.toHaveBeenCalled()
    })

    test('throws error when bridge fails to push event', async () => {
      const mockState = new Uint8Array([1, 2, 3])
      vi.mocked(mockDocumentAdapter.getCurrentState).mockResolvedValue(mockState)
      const error = new Error('Network error')
      vi.mocked(mockLiveViewBridge.pushEvent).mockRejectedValue(error)

      await expect(useCase.execute()).rejects.toThrow('Network error')
    })

    test('handles empty state', async () => {
      const emptyState = new Uint8Array([])
      vi.mocked(mockDocumentAdapter.getCurrentState).mockResolvedValue(emptyState)
      vi.mocked(mockLiveViewBridge.pushEvent).mockResolvedValue()

      await useCase.execute()

      expect(mockLiveViewBridge.pushEvent).toHaveBeenCalledWith(
        'sync-document',
        { update: '' }
      )
    })
  })

  describe('startListening', () => {
    test('registers callback with document adapter', () => {
      useCase.startListening()

      expect(mockDocumentAdapter.onUpdate).toHaveBeenCalledWith(
        expect.any(Function)
      )
    })

    test('pushes updates to LiveView when document changes', async () => {
      vi.mocked(mockLiveViewBridge.pushEvent).mockResolvedValue()

      // Capture the callback registered with the adapter
      let capturedCallback: ((update: Uint8Array, origin: string) => void) | undefined
      vi.mocked(mockDocumentAdapter.onUpdate).mockImplementation((callback) => {
        capturedCallback = callback
      })

      useCase.startListening()

      // Simulate a document update
      const update = new Uint8Array([4, 5, 6])
      capturedCallback!(update, 'local')

      // Wait for async operations
      await new Promise(resolve => setTimeout(resolve, 0))

      const expectedBase64 = btoa(String.fromCharCode(...update))
      expect(mockLiveViewBridge.pushEvent).toHaveBeenCalledWith(
        'sync-document',
        { update: expectedBase64 }
      )
    })

    test('does not push remote-origin updates back to server', async () => {
      vi.mocked(mockLiveViewBridge.pushEvent).mockResolvedValue()

      let capturedCallback: ((update: Uint8Array, origin: string) => void) | undefined
      vi.mocked(mockDocumentAdapter.onUpdate).mockImplementation((callback) => {
        capturedCallback = callback
      })

      useCase.startListening()

      // Simulate a remote update
      const update = new Uint8Array([7, 8, 9])
      capturedCallback!(update, 'remote')

      // Wait for async operations
      await new Promise(resolve => setTimeout(resolve, 0))

      // Should NOT push remote updates back to server
      expect(mockLiveViewBridge.pushEvent).not.toHaveBeenCalled()
    })

    test('handles errors during push gracefully', async () => {
      const error = new Error('Push failed')
      vi.mocked(mockLiveViewBridge.pushEvent).mockRejectedValue(error)

      let capturedCallback: ((update: Uint8Array, origin: string) => void) | undefined
      vi.mocked(mockDocumentAdapter.onUpdate).mockImplementation((callback) => {
        capturedCallback = callback
      })

      useCase.startListening()

      const update = new Uint8Array([10, 11, 12])

      // Should not throw - error should be logged/handled internally
      expect(() => capturedCallback!(update, 'local')).not.toThrow()
    })
  })
})
