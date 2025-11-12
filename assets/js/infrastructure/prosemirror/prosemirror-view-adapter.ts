/**
 * ProseMirrorViewAdapter
 *
 * Adapter that wraps ProseMirror EditorView to implement the EditorAdapter interface.
 * This enables clean architecture by decoupling use cases from ProseMirror specifics.
 *
 * Provides methods for:
 * - Inserting nodes at specific positions
 * - Deleting text ranges
 * - Getting current selection
 * - Extracting text content
 *
 * @example
 * ```typescript
 * import { EditorView } from '@milkdown/prose/view'
 * import { ProseMirrorViewAdapter } from './prosemirror-view-adapter'
 *
 * const view = new EditorView(...)
 * const adapter = new ProseMirrorViewAdapter(view)
 *
 * // Insert a node
 * adapter.insertNode(node, 10)
 *
 * // Delete a range
 * adapter.deleteRange(5, 15)
 *
 * // Get selection
 * const selection = adapter.getSelection()
 *
 * // Clean up when done
 * adapter.destroy()
 * ```
 *
 * @module infrastructure/prosemirror
 */

import type { EditorView } from '@milkdown/prose/view'
import type { EditorAdapter, EditorSelection } from '../../application/interfaces/editor-adapter.interface'

/**
 * Adapter that wraps ProseMirror EditorView
 *
 * Implements the EditorAdapter interface to provide a clean abstraction
 * over ProseMirror's EditorView API.
 */
export class ProseMirrorViewAdapter implements EditorAdapter {
  /**
   * Reference to ProseMirror EditorView (nullable after destroy)
   */
  private view: EditorView | null

  /**
   * Creates a new ProseMirrorViewAdapter
   *
   * @param view - ProseMirror EditorView instance
   * @throws {Error} If EditorView is null or undefined
   *
   * @example
   * ```typescript
   * const view = new EditorView(...)
   * const adapter = new ProseMirrorViewAdapter(view)
   * ```
   */
  constructor(view: EditorView) {
    if (!view) {
      throw new Error('EditorView is required')
    }
    this.view = view
  }

  /**
   * Insert a node into the editor at a specific position
   *
   * Creates a transaction that inserts the node and dispatches it.
   *
   * @param node - The ProseMirror node to insert
   * @param position - The position to insert at (0-based index)
   * @throws {Error} If adapter has been destroyed
   * @throws {Error} If position is negative
   *
   * @example
   * ```typescript
   * const node = schema.nodes.paragraph.create()
   * adapter.insertNode(node, 10)
   * ```
   */
  insertNode(node: any, position: number): void {
    this.ensureNotDestroyed()

    if (position < 0) {
      throw new Error('Position must be non-negative')
    }

    const tr = this.view!.state.tr
    tr.insert(position, node)
    this.view!.dispatch(tr)
  }

  /**
   * Delete a range of content from the editor
   *
   * Creates a transaction that deletes content between from and to positions.
   *
   * @param from - Start position of the range (inclusive)
   * @param to - End position of the range (exclusive)
   * @throws {Error} If adapter has been destroyed
   * @throws {Error} If positions are negative
   * @throws {Error} If from is greater than to
   *
   * @example
   * ```typescript
   * // Delete characters from position 5 to 10
   * adapter.deleteRange(5, 10)
   * ```
   */
  deleteRange(from: number, to: number): void {
    this.ensureNotDestroyed()

    if (from < 0 || to < 0) {
      throw new Error('Positions must be non-negative')
    }

    if (from > to) {
      throw new Error('From position must be less than or equal to to position')
    }

    const tr = this.view!.state.tr
    tr.delete(from, to)
    this.view!.dispatch(tr)
  }

  /**
   * Get the current selection in the editor
   *
   * Returns the current selection range from the editor state.
   *
   * @returns The current selection range
   * @throws {Error} If adapter has been destroyed
   *
   * @example
   * ```typescript
   * const selection = adapter.getSelection()
   * console.log(`Selected from ${selection.from} to ${selection.to}`)
   * ```
   */
  getSelection(): EditorSelection {
    this.ensureNotDestroyed()

    const { from, to } = this.view!.state.selection
    return { from, to }
  }

  /**
   * Get text content from a specific range
   *
   * Extracts text between the specified positions using ProseMirror's textBetween.
   *
   * @param from - Start position of the range (inclusive)
   * @param to - End position of the range (exclusive)
   * @returns The text content in the range
   * @throws {Error} If adapter has been destroyed
   * @throws {Error} If positions are negative
   * @throws {Error} If from is greater than to
   *
   * @example
   * ```typescript
   * const text = adapter.getText(0, 10)
   * console.log(`First 10 characters: ${text}`)
   * ```
   */
  getText(from: number, to: number): string {
    this.ensureNotDestroyed()

    if (from < 0 || to < 0) {
      throw new Error('Positions must be non-negative')
    }

    if (from > to) {
      throw new Error('From position must be less than or equal to to position')
    }

    return this.view!.state.doc.textBetween(from, to)
  }

  /**
   * Destroy the adapter and clean up resources
   *
   * Removes the reference to EditorView to prevent memory leaks.
   * After calling destroy, all operations will throw an error.
   *
   * @example
   * ```typescript
   * adapter.destroy()
   * // All subsequent operations will throw "Adapter has been destroyed"
   * ```
   */
  destroy(): void {
    this.view = null
  }

  /**
   * Internal helper to ensure adapter hasn't been destroyed
   *
   * @throws {Error} If adapter has been destroyed
   * @private
   */
  private ensureNotDestroyed(): void {
    if (!this.view) {
      throw new Error('Adapter has been destroyed')
    }
  }
}
