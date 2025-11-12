/**
 * AwarenessAdapter Interface
 *
 * Defines the contract for awareness operations in collaborative editing.
 * Awareness tracks user presence, cursor positions, and selections in real-time.
 *
 * This interface enables dependency inversion - use cases depend on this abstraction,
 * not on concrete Yjs awareness implementations.
 *
 * Implementations will be provided by the infrastructure layer (Phase 3).
 *
 * @example
 * ```typescript
 * // Infrastructure layer provides concrete implementation
 * class YjsAwarenessAdapter implements AwarenessAdapter {
 *   constructor(private awareness: Awareness) {}
 *
 *   setLocalState(state: Record<string, any>): void {
 *     this.awareness.setLocalState(state)
 *   }
 *
 *   onAwarenessChange(callback: (changes: AwarenessChanges) => void): void {
 *     this.awareness.on('change', callback)
 *   }
 *   // ... other methods
 * }
 *
 * // Use case depends on interface
 * class UpdateCursorPosition {
 *   constructor(private awarenessAdapter: AwarenessAdapter) {}
 *
 *   async execute(userId: string, position: number): Promise<void> {
 *     this.awarenessAdapter.setLocalState({ userId, cursor: position })
 *   }
 * }
 * ```
 *
 * @module application/interfaces
 */

/**
 * Awareness change event structure
 *
 * Describes which clients had awareness changes:
 * - added: New clients that joined
 * - updated: Existing clients with state changes
 * - removed: Clients that left or timed out
 */
export interface AwarenessChanges {
  /**
   * Array of client IDs that were added
   */
  added: number[]

  /**
   * Array of client IDs that were updated
   */
  updated: number[]

  /**
   * Array of client IDs that were removed
   */
  removed: number[]
}

/**
 * Interface for awareness operations
 *
 * Abstracts the Yjs Awareness API to enable clean architecture
 * and testability.
 */
export interface AwarenessAdapter {
  /**
   * Set the local client's awareness state
   *
   * Updates the awareness state for the local client.
   * This state is automatically shared with other clients.
   *
   * @param state - The awareness state object (user info, cursor, selection, etc.)
   *
   * @example
   * ```typescript
   * awarenessAdapter.setLocalState({
   *   userId: 'user-123',
   *   userName: 'John Doe',
   *   cursor: 42,
   *   selection: { anchor: 10, head: 20 }
   * })
   * ```
   */
  setLocalState(state: Record<string, any>): void

  /**
   * Register a callback for awareness changes
   *
   * The callback is invoked when any client's awareness state changes
   * (including the local client).
   *
   * @param callback - Function called when awareness changes occur
   *
   * @example
   * ```typescript
   * awarenessAdapter.onAwarenessChange((changes) => {
   *   console.log('Added clients:', changes.added)
   *   console.log('Updated clients:', changes.updated)
   *   console.log('Removed clients:', changes.removed)
   * })
   * ```
   */
  onAwarenessChange(callback: (changes: AwarenessChanges) => void): void

  /**
   * Encode awareness update for specific clients
   *
   * Creates a binary update containing awareness state for the specified client IDs.
   * This is used to broadcast awareness changes to other clients.
   *
   * @param clientIds - Array of client IDs to encode
   * @returns Binary update that can be sent over the network
   *
   * @example
   * ```typescript
   * const update = awarenessAdapter.encodeUpdate([1, 2, 3])
   * // Send update to server
   * bridge.pushEvent('awareness-update', { update })
   * ```
   */
  encodeUpdate(clientIds: number[]): Uint8Array

  /**
   * Apply a remote awareness update
   *
   * Merges awareness state from other clients into the local awareness.
   * The origin parameter helps track where the update came from.
   *
   * @param update - Binary update received from the network
   * @param origin - Optional origin identifier (e.g., 'remote', 'local')
   *
   * @example
   * ```typescript
   * // Apply update received from server
   * awarenessAdapter.applyUpdate(updateData, 'remote')
   * ```
   */
  applyUpdate(update: Uint8Array, origin?: string): void
}
