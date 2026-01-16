/**
 * YjsAwarenessAdapter - Infrastructure Layer
 *
 * Wraps Yjs Awareness for collaborative cursor/selection tracking.
 * This adapter implements the AwarenessAdapter interface defined in the application layer,
 * enabling dependency inversion and clean architecture.
 *
 * Infrastructure Layer Characteristics:
 * - Wraps external library (y-protocols/awareness) behind clean interface
 * - Handles binary data encoding/decoding for awareness updates
 * - Manages Yjs-specific details (Awareness, client IDs, state updates)
 * - Provides resource cleanup via destroy()
 *
 * @module infrastructure/yjs
 */

import { Awareness, encodeAwarenessUpdate, applyAwarenessUpdate } from 'y-protocols/awareness'
import type { AwarenessAdapter, AwarenessChanges } from '../../application/interfaces/awareness-adapter.interface'

/**
 * Yjs implementation of AwarenessAdapter
 *
 * Wraps Yjs Awareness for tracking user presence, cursor positions, and selections.
 * Handles awareness updates, state management, and event listening.
 *
 * @implements {AwarenessAdapter}
 */
export class YjsAwarenessAdapter implements AwarenessAdapter {
  private awareness: Awareness
  private changeCallbacks: Array<(changes: AwarenessChanges) => void> = []
  private destroyed: boolean = false

  /**
   * Creates a new YjsAwarenessAdapter
   *
   * @param awareness - Yjs Awareness instance
   * @throws Error if awareness is null or undefined
   */
  constructor(awareness: Awareness) {
    if (!awareness) {
      throw new Error('Awareness instance is required')
    }

    this.awareness = awareness

    // Set up awareness change listener
    this.awareness.on('change', this.handleAwarenessChange)
  }

  /**
   * Get the underlying Awareness instance
   * Exposed for integration with ProseMirror plugins
   */
  getAwareness(): Awareness {
    return this.awareness
  }

  /**
   * Internal handler for Yjs awareness change events
   *
   * @param changes - Changes object from Yjs with added/updated/removed client IDs
   * @param _origin - Origin of the change (unused)
   */
  private handleAwarenessChange = (changes: { added: Set<number>; updated: Set<number>; removed: Set<number> }, _origin: any) => {
    if (this.destroyed) return

    // Convert Yjs change format to our interface format
    const awarenessChanges: AwarenessChanges = {
      added: Array.from(changes.added || new Set<number>()),
      updated: Array.from(changes.updated || new Set<number>()),
      removed: Array.from(changes.removed || new Set<number>())
    }

    // Notify all registered callbacks
    this.changeCallbacks.forEach(callback => {
      callback(awarenessChanges)
    })
  }

  /**
   * Set the local client's awareness state
   *
   * @param state - The awareness state object (user info, cursor, selection, etc.)
   */
  setLocalState(state: Record<string, any>): void {
    if (this.destroyed) {
      throw new Error('Adapter has been destroyed')
    }

    this.awareness.setLocalState(state)
  }

  /**
   * Register a callback for awareness changes
   *
   * @param callback - Function called when awareness changes occur
   */
  onAwarenessChange(callback: (changes: AwarenessChanges) => void): void {
    if (this.destroyed) {
      throw new Error('Adapter has been destroyed')
    }

    this.changeCallbacks.push(callback)
  }

  /**
   * Encode awareness update for specific clients
   *
   * @param clientIds - Array of client IDs to encode
   * @returns Binary update that can be sent over the network
   */
  encodeUpdate(clientIds: number[]): Uint8Array {
    if (this.destroyed) {
      throw new Error('Adapter has been destroyed')
    }

    return encodeAwarenessUpdate(this.awareness, clientIds)
  }

  /**
   * Apply a remote awareness update
   *
   * @param update - Binary update received from the network
   * @param origin - Optional origin identifier (e.g., 'remote', 'local')
   */
  applyUpdate(update: Uint8Array, origin?: string): void {
    if (this.destroyed) {
      throw new Error('Adapter has been destroyed')
    }

    // Handle empty updates gracefully
    if (update.length === 0) {
      return
    }

    applyAwarenessUpdate(this.awareness, update, origin)
  }

  /**
   * Clean up resources
   *
   * Removes all event listeners and marks adapter as destroyed.
   * After calling destroy(), the adapter should not be used.
   */
  destroy(): void {
    if (this.destroyed) return

    this.destroyed = true

    // Remove awareness change listener
    this.awareness.off('change', this.handleAwarenessChange)

    // Clear all callbacks
    this.changeCallbacks = []
  }
}
