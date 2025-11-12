/**
 * HandleDocumentSync - Application Layer Use Case
 *
 * Manages bidirectional synchronization of document changes between local editor and server.
 * This use case coordinates Yjs document updates with LiveView backend communication.
 *
 * Responsibilities:
 * - Listen for local document changes
 * - Encode and send changes to server
 * - Receive and apply remote changes from server
 * - Extract markdown content for server storage
 *
 * Application Layer Characteristics:
 * - Orchestrates document sync workflow
 * - Depends only on interfaces
 * - Contains coordination logic
 * - Framework-agnostic
 *
 * @module application/use-cases
 */

import type { YjsDocumentAdapter } from '../../infrastructure/yjs/yjs-document-adapter'
import type { MilkdownEditorAdapter } from '../../infrastructure/milkdown/milkdown-editor-adapter'
import { serializerCtx, editorViewCtx } from '@milkdown/core'

/**
 * Configuration for document sync
 */
export interface DocumentSyncConfig {
  yjsDocumentAdapter: YjsDocumentAdapter
  milkdownAdapter: MilkdownEditorAdapter
  userId: string
  onLocalChange: (update: string, markdown: string, completeState: string) => void
  onRemoteChange?: (update: Uint8Array) => void
}

/**
 * Use case for handling document synchronization
 *
 * Manages the bidirectional flow of document changes:
 * - Local changes: Editor → Yjs → Server
 * - Remote changes: Server → Yjs → Editor
 *
 * Usage:
 * ```typescript
 * const useCase = new HandleDocumentSync()
 * const cleanup = useCase.execute({
 *   yjsDocumentAdapter,
 *   milkdownAdapter,
 *   userId: 'user-123',
 *   onLocalChange: (update, markdown, state) => {
 *     pushEvent('yjs_update', { update, markdown, complete_state: state })
 *   }
 * })
 * ```
 */
export class HandleDocumentSync {
  /**
   * Execute the use case
   *
   * Sets up bidirectional sync and returns cleanup function.
   *
   * @param config - Configuration for document sync
   * @returns Cleanup function to stop sync
   */
  execute(config: DocumentSyncConfig): () => void {
    const {
      yjsDocumentAdapter,
      milkdownAdapter,
      onLocalChange
    } = config

    // Track if we've already cleaned up
    let isCleanedUp = false

    // Listen for local Yjs updates
    const handleLocalUpdate = (update: Uint8Array, origin: string) => {
      if (isCleanedUp) return

      // Only propagate local changes (not remote-originated changes)
      if (origin === 'remote') return

      // Encode update as base64 for transmission
      const updateBase64 = this.encodeBase64(update)

      // Extract markdown content
      const markdown = this.getMarkdownContent(milkdownAdapter)

      // Get complete Yjs state
      yjsDocumentAdapter.getCurrentState().then(completeState => {
        const completeStateBase64 = this.encodeBase64(completeState)

        // Notify callback with encoded data
        onLocalChange(updateBase64, markdown, completeStateBase64)
      })
    }

    // Register local update listener
    yjsDocumentAdapter.onUpdate(handleLocalUpdate)

    // Return cleanup function
    return () => {
      if (isCleanedUp) return
      isCleanedUp = true

      // Cleanup is handled by adapter destroy() methods
      // No additional cleanup needed here
    }
  }

  /**
   * Apply a remote update to the document
   *
   * @param yjsDocumentAdapter - Yjs document adapter
   * @param updateBase64 - Base64 encoded update from server
   */
  applyRemoteUpdate(yjsDocumentAdapter: YjsDocumentAdapter, updateBase64: string): void {
    const update = this.decodeBase64(updateBase64)
    yjsDocumentAdapter.applyUpdate(update, 'remote')
  }

  /**
   * Get markdown content from editor
   *
   * @param milkdownAdapter - Milkdown editor adapter
   * @returns Markdown string
   */
  private getMarkdownContent(milkdownAdapter: MilkdownEditorAdapter): string {
    let markdown = ''

    milkdownAdapter.action((ctx) => {
      try {
        const editorView = ctx.get(editorViewCtx)
        const serializer = ctx.get(serializerCtx)

        if (serializer && editorView) {
          markdown = serializer(editorView.state.doc)
        }
      } catch (error) {
        console.error('Error extracting markdown:', error)
      }
    })

    return markdown
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
