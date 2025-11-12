/**
 * LiveViewBridge Interface
 *
 * Defines the contract for communication between frontend JavaScript and Phoenix LiveView.
 * This interface enables dependency inversion - use cases depend on this abstraction,
 * not on concrete Phoenix hook implementations.
 *
 * Implementations will be provided by the infrastructure layer (Phase 3).
 *
 * @example
 * ```typescript
 * // Infrastructure layer provides concrete implementation
 * class PhoenixLiveViewBridge implements LiveViewBridge {
 *   constructor(private hook: any) {}
 *
 *   async pushEvent(event: string, payload: Record<string, any>): Promise<void> {
 *     return new Promise((resolve) => {
 *       this.hook.pushEvent(event, payload, () => resolve())
 *     })
 *   }
 *   // ... other methods
 * }
 *
 * // Use case depends on interface
 * class SyncDocumentChanges {
 *   constructor(private bridge: LiveViewBridge) {}
 *
 *   async execute(update: Uint8Array): Promise<void> {
 *     await this.bridge.pushEvent('document-update', { update })
 *   }
 * }
 * ```
 *
 * @module application/interfaces
 */

/**
 * Interface for Phoenix LiveView communication
 *
 * Abstracts the Phoenix LiveView hook API to enable clean architecture
 * and testability.
 */
export interface LiveViewBridge {
  /**
   * Push an event to the LiveView server
   *
   * Sends a named event with a payload to the Phoenix LiveView server.
   * The server can handle this event in the LiveView module.
   *
   * @param event - Name of the event to push
   * @param payload - Data to send with the event
   * @returns Promise that resolves when event is sent
   *
   * @example
   * ```typescript
   * await bridge.pushEvent('document-update', {
   *   documentId: 'doc-123',
   *   update: encodedUpdate
   * })
   * ```
   */
  pushEvent(event: string, payload: Record<string, any>): Promise<void>

  /**
   * Register a callback for events from the LiveView server
   *
   * The callback is invoked when the LiveView server pushes an event
   * to the client using push_event/3 in Elixir.
   *
   * @param event - Name of the event to listen for
   * @param callback - Function called when event is received
   *
   * @example
   * ```typescript
   * bridge.handleEvent('remote-update', (payload) => {
   *   const { update, userId } = payload
   *   applyRemoteUpdate(update, userId)
   * })
   * ```
   */
  handleEvent(event: string, callback: (payload: any) => void): void
}
