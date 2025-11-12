/**
 * Tests for ApplyRemoteChanges use case
 *
 * Following TDD: Write tests FIRST, then implement.
 * Tests use mocked dependencies (DocumentAdapter).
 *
 * @module __tests__/application/use-cases
 */

import { describe, test, expect, vi, beforeEach } from 'vitest'
import { ApplyRemoteChanges } from '../../../application/use-cases/apply-remote-changes'
import type { DocumentAdapter } from '../../../application/interfaces/document-adapter.interface'

describe('ApplyRemoteChanges', () => {
  let mockDocumentAdapter: DocumentAdapter
  let useCase: ApplyRemoteChanges

  beforeEach(() => {
    // Create mock DocumentAdapter
    mockDocumentAdapter = {
      applyUpdate: vi.fn(),
      getCurrentState: vi.fn(),
      onUpdate: vi.fn()
    }

    // Create use case with mocked dependency
    useCase = new ApplyRemoteChanges(mockDocumentAdapter)
  })

  describe('execute', () => {
    test('decodes base64 update to Uint8Array', async () => {
      const base64Update = btoa(String.fromCharCode(1, 2, 3))
      vi.mocked(mockDocumentAdapter.applyUpdate).mockResolvedValue()

      await useCase.execute(base64Update, 'user-123')

      expect(mockDocumentAdapter.applyUpdate).toHaveBeenCalledWith(
        expect.any(Uint8Array),
        'remote'
      )

      const calledWith = vi.mocked(mockDocumentAdapter.applyUpdate).mock.calls[0][0]
      expect(Array.from(calledWith)).toEqual([1, 2, 3])
    })

    test('applies update with remote origin', async () => {
      const base64Update = btoa(String.fromCharCode(4, 5, 6))
      vi.mocked(mockDocumentAdapter.applyUpdate).mockResolvedValue()

      await useCase.execute(base64Update, 'user-456')

      expect(mockDocumentAdapter.applyUpdate).toHaveBeenCalledWith(
        expect.any(Uint8Array),
        'remote'
      )
    })

    test('passes update data correctly', async () => {
      const originalData = new Uint8Array([7, 8, 9, 10])
      const base64Update = btoa(String.fromCharCode(...originalData))
      vi.mocked(mockDocumentAdapter.applyUpdate).mockResolvedValue()

      await useCase.execute(base64Update, 'user-789')

      const calledWith = vi.mocked(mockDocumentAdapter.applyUpdate).mock.calls[0][0]
      expect(Array.from(calledWith)).toEqual(Array.from(originalData))
    })

    test('throws error when adapter fails to apply update', async () => {
      const base64Update = btoa(String.fromCharCode(1, 2, 3))
      const error = new Error('Failed to apply update')
      vi.mocked(mockDocumentAdapter.applyUpdate).mockRejectedValue(error)

      await expect(useCase.execute(base64Update, 'user-123')).rejects.toThrow(
        'Failed to apply update'
      )
    })

    test('throws error for invalid base64 string', async () => {
      const invalidBase64 = 'not-valid-base64!!!'

      await expect(useCase.execute(invalidBase64, 'user-123')).rejects.toThrow()
    })

    test('handles empty update', async () => {
      const emptyUpdate = ''
      vi.mocked(mockDocumentAdapter.applyUpdate).mockResolvedValue()

      await useCase.execute(emptyUpdate, 'user-123')

      expect(mockDocumentAdapter.applyUpdate).toHaveBeenCalledWith(
        expect.any(Uint8Array),
        'remote'
      )

      const calledWith = vi.mocked(mockDocumentAdapter.applyUpdate).mock.calls[0][0]
      expect(calledWith.length).toBe(0)
    })

    test('handles large updates', async () => {
      const largeData = new Uint8Array(1000).fill(255)
      const base64Update = btoa(String.fromCharCode(...largeData))
      vi.mocked(mockDocumentAdapter.applyUpdate).mockResolvedValue()

      await useCase.execute(base64Update, 'user-large')

      const calledWith = vi.mocked(mockDocumentAdapter.applyUpdate).mock.calls[0][0]
      expect(calledWith.length).toBe(1000)
      expect(Array.from(calledWith)).toEqual(Array.from(largeData))
    })

    test('accepts userId parameter for tracking', async () => {
      const base64Update = btoa(String.fromCharCode(1, 2, 3))
      vi.mocked(mockDocumentAdapter.applyUpdate).mockResolvedValue()

      // UserId is for tracking/logging, doesn't affect adapter call
      await useCase.execute(base64Update, 'user-tracking-123')

      expect(mockDocumentAdapter.applyUpdate).toHaveBeenCalledOnce()
    })
  })

  describe('validation', () => {
    test('validates update is from remote source', async () => {
      const base64Update = btoa(String.fromCharCode(1, 2, 3))
      vi.mocked(mockDocumentAdapter.applyUpdate).mockResolvedValue()

      await useCase.execute(base64Update, 'user-remote')

      // Verify it always uses 'remote' origin (not the userId)
      expect(mockDocumentAdapter.applyUpdate).toHaveBeenCalledWith(
        expect.any(Uint8Array),
        'remote'
      )
    })
  })
})
