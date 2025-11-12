/**
 * ApplyRemoteChanges Use Case
 *
 * Orchestrates applying remote document changes received from other users.
 * This use case decodes updates from the server and applies them to the local document.
 *
 * Following Clean Architecture:
 * - Depends on interfaces (DocumentAdapter), not concrete implementations
 * - Handles orchestration and side effects
 * - No business logic (that's in domain layer)
 * - Converts between infrastructure formats and domain operations
 *
 * @example
 * ```typescript
 * const adapter = new YjsDocumentAdapter(ydoc)
 * const useCase = new ApplyRemoteChanges(adapter)
 *
 * // Apply update from server
 * await useCase.execute(base64Update, 'user-123')
 * ```
 *
 * @module application/use-cases
 */

import type { DocumentAdapter } from '../interfaces/document-adapter.interface'

export class ApplyRemoteChanges {
  /**
   * Creates a new ApplyRemoteChanges use case
   *
   * @param documentAdapter - Adapter for document operations (injected)
   */
  constructor(private readonly documentAdapter: DocumentAdapter) {}

  /**
   * Execute applying a remote document change
   *
   * Decodes the base64-encoded update and applies it to the local document
   * with 'remote' origin to prevent sync loops.
   *
   * @param updateBase64 - Base64-encoded document update
   * @param userId - ID of the user who made the change (for tracking)
   * @returns Promise that resolves when update is applied
   * @throws Error if decoding fails or adapter operation fails
   */
  async execute(updateBase64: string, _userId: string): Promise<void> {
    const update = this.decodeFromBase64(updateBase64)
    await this.documentAdapter.applyUpdate(update, 'remote')
  }

  /**
   * Decode base64 string to Uint8Array
   *
   * @param base64 - Base64-encoded string
   * @returns Decoded binary data
   * @throws Error if base64 string is invalid
   */
  private decodeFromBase64(base64: string): Uint8Array {
    try {
      const binaryString = atob(base64)
      const bytes = new Uint8Array(binaryString.length)
      for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i)
      }
      return bytes
    } catch (error) {
      throw new Error(`Failed to decode base64 update: ${error}`)
    }
  }
}
