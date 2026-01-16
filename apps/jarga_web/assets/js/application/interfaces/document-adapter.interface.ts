/**
 * DocumentAdapter Interface
 *
 * Defines the contract for document operations that interact with external systems.
 * This interface enables dependency inversion - use cases depend on this abstraction,
 * not on concrete implementations (Yjs, ProseMirror, etc.).
 *
 * Implementations will be provided by the infrastructure layer (Phase 3).
 *
 * @example
 * ```typescript
 * // Infrastructure layer provides concrete implementation
 * class YjsDocumentAdapter implements DocumentAdapter {
 *   async applyUpdate(update: Uint8Array, origin?: string): Promise<void> {
 *     Y.applyUpdate(this.ydoc, update, origin)
 *   }
 *   // ... other methods
 * }
 *
 * // Use case depends on interface
 * class ApplyRemoteChanges {
 *   constructor(private adapter: DocumentAdapter) {}
 *
 *   async execute(updateBase64: string): Promise<void> {
 *     const update = this.decodeBase64(updateBase64)
 *     await this.adapter.applyUpdate(update, 'remote')
 *   }
 * }
 * ```
 *
 * @module application/interfaces
 */

/**
 * Interface for document synchronization operations
 *
 * Abstracts the underlying document technology (Yjs, Automerge, etc.)
 * to enable clean architecture and testability.
 */
export interface DocumentAdapter {
  /**
   * Apply an update to the document
   *
   * Updates are represented as binary data (Uint8Array) that encodes
   * changes to the document structure. The origin parameter helps
   * distinguish between local and remote updates.
   *
   * @param update - Binary update data to apply
   * @param origin - Origin of the update (e.g., 'remote', 'local')
   * @returns Promise that resolves when update is applied
   *
   * @example
   * ```typescript
   * const update = new Uint8Array([...])
   * await adapter.applyUpdate(update, 'remote')
   * ```
   */
  applyUpdate(update: Uint8Array, origin?: string): Promise<void>

  /**
   * Get the current state of the document
   *
   * Returns the complete document state as binary data.
   * This can be used for synchronization or persistence.
   *
   * @returns Promise that resolves to current document state
   *
   * @example
   * ```typescript
   * const state = await adapter.getCurrentState()
   * // Save state to database or send over network
   * ```
   */
  getCurrentState(): Promise<Uint8Array>

  /**
   * Register a callback for document updates
   *
   * The callback is invoked whenever the document changes.
   * The origin parameter indicates whether the change was local or remote.
   *
   * @param callback - Function called with update data and origin
   *
   * @example
   * ```typescript
   * adapter.onUpdate((update, origin) => {
   *   if (origin !== 'remote') {
   *     // This is a local change, send to server
   *     sendToServer(update)
   *   }
   * })
   * ```
   */
  onUpdate(callback: (update: Uint8Array, origin: string) => void): void
}
