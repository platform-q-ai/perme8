/**
 * HandleAwarenessSync - Application Layer Use Case
 *
 * Manages bidirectional synchronization of user awareness (cursors, selections, presence).
 * This use case coordinates Yjs awareness updates with LiveView backend communication.
 *
 * Responsibilities:
 * - Listen for local awareness changes
 * - Encode and send changes to server
 * - Receive and apply remote awareness updates
 * - Track user presence and cursor positions
 *
 * Application Layer Characteristics:
 * - Orchestrates awareness sync workflow
 * - Depends only on interfaces
 * - Contains coordination logic
 * - Framework-agnostic
 *
 * @module application/use-cases
 */

import type { YjsAwarenessAdapter } from '../../infrastructure/yjs/yjs-awareness-adapter'
import type { AwarenessChanges } from '../interfaces/awareness-adapter.interface'

/**
 * Configuration for awareness sync
 */
export interface AwarenessSyncConfig {
  yjsAwarenessAdapter: YjsAwarenessAdapter
  userId: string
  onLocalChange: (update: string) => void
}

/**
 * Use case for handling awareness synchronization
 *
 * Manages the bidirectional flow of awareness updates:
 * - Local changes: User actions → Yjs Awareness → Server
 * - Remote changes: Server → Yjs Awareness → UI
 *
 * Usage:
 * ```typescript
 * const useCase = new HandleAwarenessSync()
 * const cleanup = useCase.execute({
 *   yjsAwarenessAdapter,
 *   userId: 'user-123',
 *   onLocalChange: (update) => {
 *     pushEvent('awareness_update', { update })
 *   }
 * })
 * ```
 */
export class HandleAwarenessSync {
  /**
   * Execute the use case
   *
   * Sets up bidirectional sync and returns cleanup function.
   *
   * @param config - Configuration for awareness sync
   * @returns Cleanup function to stop sync
   */
  execute(config: AwarenessSyncConfig): () => void {
    const {
      yjsAwarenessAdapter,
      onLocalChange
    } = config

    // Track if we've already cleaned up
    let isCleanedUp = false

    // Get local client ID from awareness
    const awareness = yjsAwarenessAdapter.getAwareness()
    const localClientId = awareness.clientID

    // Listen for awareness changes
    const handleAwarenessChange = (changes: AwarenessChanges) => {
      if (isCleanedUp) return

      // Only broadcast if local client changed
      const hasLocalChange =
        changes.added.includes(localClientId) ||
        changes.updated.includes(localClientId)

      if (!hasLocalChange) return

      // Encode awareness update for changed clients
      const clientIds = [...changes.added, ...changes.updated]
      const update = yjsAwarenessAdapter.encodeUpdate(clientIds)
      const updateBase64 = this.encodeBase64(update)

      // Notify callback
      onLocalChange(updateBase64)
    }

    // Register awareness change listener
    yjsAwarenessAdapter.onAwarenessChange(handleAwarenessChange)

    // Return cleanup function
    return () => {
      if (isCleanedUp) return
      isCleanedUp = true

      // Cleanup is handled by adapter destroy() methods
      // No additional cleanup needed here
    }
  }

  /**
   * Apply a remote awareness update
   *
   * @param yjsAwarenessAdapter - Yjs awareness adapter
   * @param updateBase64 - Base64 encoded update from server
   */
  applyRemoteUpdate(yjsAwarenessAdapter: YjsAwarenessAdapter, updateBase64: string): void {
    const update = this.decodeBase64(updateBase64)
    yjsAwarenessAdapter.applyUpdate(update, 'remote')
  }

  /**
   * Encode binary data to base64
   *
   * @param data - Binary data
   * @returns Base64 string
   */
  private encodeBase64(data: Uint8Array): string {
    return btoa(String.fromCharCode(...data))
  }

  /**
   * Decode base64 to binary data
   *
   * @param base64 - Base64 string
   * @returns Binary data
   */
  private decodeBase64(base64: string): Uint8Array {
    return Uint8Array.from(atob(base64), c => c.charCodeAt(0))
  }
}
