/**
 * SyncDocumentChanges Use Case
 *
 * Orchestrates syncing local document changes to the LiveView server.
 * This use case coordinates between the DocumentAdapter (Yjs) and LiveViewBridge (Phoenix).
 *
 * Following Clean Architecture:
 * - Depends on interfaces (DocumentAdapter, LiveViewBridge), not concrete implementations
 * - Handles orchestration and side effects
 * - No business logic (that's in domain layer)
 * - Converts between domain types and infrastructure formats
 *
 * @example
 * ```typescript
 * const adapter = new YjsDocumentAdapter(ydoc)
 * const bridge = new PhoenixLiveViewBridge(hook)
 * const useCase = new SyncDocumentChanges(adapter, bridge)
 *
 * // One-time sync
 * await useCase.execute()
 *
 * // Continuous sync
 * useCase.startListening()
 * ```
 *
 * @module application/use-cases
 */

import type { DocumentAdapter } from '../interfaces/document-adapter.interface'
import type { LiveViewBridge } from '../interfaces/liveview-bridge.interface'

export class SyncDocumentChanges {
  /**
   * Creates a new SyncDocumentChanges use case
   *
   * @param documentAdapter - Adapter for document operations (injected)
   * @param liveViewBridge - Bridge for LiveView communication (injected)
   */
  constructor(
    private readonly documentAdapter: DocumentAdapter,
    private readonly liveViewBridge: LiveViewBridge
  ) {}

  /**
   * Execute a one-time sync of current document state
   *
   * Gets the current document state and pushes it to the LiveView server.
   * Used for initial sync or on-demand synchronization.
   *
   * @returns Promise that resolves when sync is complete
   * @throws Error if adapter or bridge operations fail
   */
  async execute(): Promise<void> {
    const state = await this.documentAdapter.getCurrentState()
    const encodedUpdate = this.encodeToBase64(state)
    await this.liveViewBridge.pushEvent('sync-document', { update: encodedUpdate })
  }

  /**
   * Start listening for document changes and sync them automatically
   *
   * Registers a callback with the document adapter to receive updates.
   * Only local updates (not remote ones) are pushed to the server to avoid loops.
   */
  startListening(): void {
    this.documentAdapter.onUpdate((update, origin) => {
      if (origin === 'remote') {
        return
      }

      const encodedUpdate = this.encodeToBase64(update)
      this.liveViewBridge
        .pushEvent('sync-document', { update: encodedUpdate })
        .catch((error) => {
          console.error('Failed to push document update:', error)
        })
    })
  }

  /**
   * Encode Uint8Array to base64 string
   *
   * @param data - Binary data to encode
   * @returns Base64-encoded string
   */
  private encodeToBase64(data: Uint8Array): string {
    return btoa(String.fromCharCode(...data))
  }
}
