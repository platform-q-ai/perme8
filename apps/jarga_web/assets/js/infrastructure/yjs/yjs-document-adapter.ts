/**
 * YjsDocumentAdapter - Infrastructure Layer
 *
 * Wraps Yjs Y.Doc and Y.XmlFragment to provide document synchronization operations.
 * This adapter implements the DocumentAdapter interface defined in the application layer,
 * enabling dependency inversion and clean architecture.
 *
 * Infrastructure Layer Characteristics:
 * - Wraps external library (Yjs) behind clean interface
 * - Handles binary data encoding/decoding
 * - Manages Yjs-specific details (Y.Doc, Y.XmlFragment, updates)
 * - Provides resource cleanup via destroy()
 *
 * @module infrastructure/yjs
 */

import * as Y from 'yjs'
import type { DocumentAdapter } from '../../application/interfaces/document-adapter.interface'

/**
 * Yjs implementation of DocumentAdapter
 *
 * Wraps Y.Doc and Y.XmlFragment for collaborative document editing.
 * Handles Yjs updates, state management, and event listening.
 *
 * @implements {DocumentAdapter}
 */
export class YjsDocumentAdapter implements DocumentAdapter {
  private ydoc: Y.Doc
  private yXmlFragment: Y.XmlFragment
  private updateCallbacks: Array<(update: Uint8Array, origin: string) => void> = []
  private destroyed: boolean = false

  /**
   * Get the underlying Y.Doc instance
   * Exposed for integration with ProseMirror plugins
   */
  getYDoc(): Y.Doc {
    return this.ydoc
  }

  /**
   * Get the underlying Y.XmlFragment instance
   * Exposed for integration with ProseMirror plugins
   */
  getYXmlFragment(): Y.XmlFragment {
    return this.yXmlFragment
  }

  /**
   * Creates a new YjsDocumentAdapter
   *
   * @param initialStateBase64 - Optional base64-encoded initial Yjs state
   */
  constructor(initialStateBase64?: string) {
    this.ydoc = new Y.Doc()
    this.yXmlFragment = this.ydoc.get('prosemirror', Y.XmlFragment)

    // Apply initial state if provided
    if (initialStateBase64 && initialStateBase64.length > 0) {
      try {
        const stateArray = Uint8Array.from(atob(initialStateBase64), c => c.charCodeAt(0))
        Y.applyUpdate(this.ydoc, stateArray)
      } catch (error) {
        console.error('Error applying initial Yjs state:', error)
      }
    }

    // Set up update listener
    this.ydoc.on('update', this.handleYjsUpdate)
  }

  /**
   * Internal handler for Yjs update events
   *
   * @param update - Binary update from Yjs
   * @param origin - Origin of the update
   */
  private handleYjsUpdate = (update: Uint8Array, origin: any) => {
    if (this.destroyed) return

    const originString = typeof origin === 'string' ? origin : 'unknown'

    // Notify all registered callbacks
    this.updateCallbacks.forEach(callback => {
      callback(update, originString)
    })
  }

  /**
   * Apply an update to the document
   *
   * @param update - Binary update data to apply
   * @param origin - Origin of the update (e.g., 'remote', 'local')
   */
  async applyUpdate(update: Uint8Array, origin?: string): Promise<void> {
    if (this.destroyed) {
      // Silently ignore updates after destroy (graceful degradation)
      return
    }

    // Handle empty updates gracefully
    if (update.length === 0) {
      return
    }

    Y.applyUpdate(this.ydoc, update, origin)
  }

  /**
   * Get the current state of the document
   *
   * @returns Current document state as binary data
   */
  async getCurrentState(): Promise<Uint8Array> {
    if (this.destroyed) {
      throw new Error('Adapter has been destroyed')
    }

    return Y.encodeStateAsUpdate(this.ydoc)
  }

  /**
   * Register a callback for document updates
   *
   * @param callback - Function called with update data and origin
   */
  onUpdate(callback: (update: Uint8Array, origin: string) => void): void {
    if (this.destroyed) {
      throw new Error('Adapter has been destroyed')
    }

    this.updateCallbacks.push(callback)
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

    // Remove Yjs update listener
    this.ydoc.off('update', this.handleYjsUpdate)

    // Clear all callbacks
    this.updateCallbacks = []

    // Destroy Yjs document
    this.ydoc.destroy()
  }
}
