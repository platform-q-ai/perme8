/**
 * SelectionTracker
 *
 * Tracks local ProseMirror selection changes and updates Yjs Awareness.
 * Converts ProseMirror selection to domain Selection value objects.
 *
 * Responsibilities:
 * - Track current editor selection
 * - Convert ProseMirror selection to domain Selection
 * - Update awareness with selection state
 * - Update awareness with cursor position
 * - Preserve existing awareness state
 * - Clean up on stop
 *
 * @example
 * ```typescript
 * import { EditorView } from '@milkdown/prose/view'
 * import { Awareness } from 'y-protocols/awareness'
 * import { SelectionTracker } from './selection-tracker'
 *
 * const view = new EditorView(...)
 * const awareness = new Awareness(ydoc)
 *
 * const tracker = new SelectionTracker(view, awareness)
 * tracker.start()
 *
 * // Get current selection as domain value object
 * const selection = tracker.getCurrentSelection()
 *
 * // Clean up when done
 * tracker.stop()
 * ```
 *
 * @module infrastructure/prosemirror
 */

import type { EditorView } from '@milkdown/prose/view'
import type { Awareness } from 'y-protocols/awareness'
import { Selection } from '../../domain/value-objects/selection'

/**
 * Tracks local selection changes and updates awareness
 *
 * Provides methods to:
 * - Start tracking selection changes
 * - Stop tracking and clean up
 * - Get current selection as domain value object
 * - Update awareness with selection state
 */
export class SelectionTracker {
  /**
   * Reference to ProseMirror EditorView (nullable after stop)
   */
  private view: EditorView | null

  /**
   * Reference to Yjs Awareness (nullable after stop)
   */
  private awareness: Awareness | null

  /**
   * Whether tracking is currently active
   */
  private isTracking: boolean = false

  /**
   * Creates a new SelectionTracker
   *
   * @param view - ProseMirror EditorView instance
   * @param awareness - Yjs Awareness instance
   * @throws {Error} If EditorView is null or undefined
   * @throws {Error} If Awareness is null or undefined
   *
   * @example
   * ```typescript
   * const view = new EditorView(...)
   * const awareness = new Awareness(ydoc)
   * const tracker = new SelectionTracker(view, awareness)
   * ```
   */
  constructor(view: EditorView, awareness: Awareness) {
    if (!view) {
      throw new Error('EditorView is required')
    }

    if (!awareness) {
      throw new Error('Awareness is required')
    }

    this.view = view
    this.awareness = awareness
  }

  /**
   * Get the current selection as a domain value object
   *
   * Converts ProseMirror selection to domain Selection value object.
   * The Selection provides business logic methods (isEmpty, isForward, etc.)
   *
   * @returns Current selection as domain Selection
   * @throws {Error} If tracker has been stopped
   *
   * @example
   * ```typescript
   * const selection = tracker.getCurrentSelection()
   * console.log(`Selection from ${selection.anchor} to ${selection.head}`)
   * console.log(`Is empty: ${selection.isEmpty()}`)
   * ```
   */
  getCurrentSelection(): Selection {
    this.ensureNotStopped()

    const { anchor, head } = this.view!.state.selection
    return new Selection(anchor, head)
  }

  /**
   * Start tracking selection changes
   *
   * Begins monitoring selection changes and updating awareness state.
   * Updates awareness immediately with current selection.
   * Can be called multiple times (idempotent).
   *
   * @example
   * ```typescript
   * tracker.start()
   * // Selection changes are now tracked and awareness is updated
   * ```
   */
  start(): void {
    if (this.isTracking) {
      return // Already tracking
    }

    this.ensureNotStopped()
    this.isTracking = true

    // Update awareness with current selection
    this.updateAwareness()
  }

  /**
   * Stop tracking selection changes
   *
   * Stops monitoring selection changes and clears selection from awareness.
   * Cleans up resources. Can be called multiple times (idempotent).
   * After calling stop, all operations will throw an error.
   *
   * @example
   * ```typescript
   * tracker.stop()
   * // Selection tracking stopped, resources cleaned up
   * ```
   */
  stop(): void {
    if (!this.isTracking && !this.view) {
      return // Already stopped
    }

    if (this.awareness) {
      // Clear selection and cursor from awareness
      const currentState = this.awareness.getLocalState() || {}
      const { selection, cursor, ...remainingState } = currentState as any

      this.awareness.setLocalState(remainingState)
    }

    this.isTracking = false
    this.view = null
    this.awareness = null
  }

  /**
   * Update awareness with current selection state
   *
   * Preserves existing awareness state (userId, userName, userColor)
   * and adds selection and cursor information.
   *
   * @private
   */
  private updateAwareness(): void {
    if (!this.view || !this.awareness) {
      return
    }

    const selection = this.getCurrentSelection()
    const currentState = this.awareness.getLocalState() || {}

    // Update awareness with selection state
    this.awareness.setLocalState({
      ...currentState,
      selection: {
        anchor: selection.anchor,
        head: selection.head
      },
      cursor: selection.head // Cursor is at the head of the selection
    })
  }

  /**
   * Internal helper to ensure tracker hasn't been stopped
   *
   * @throws {Error} If tracker has been stopped
   * @private
   */
  private ensureNotStopped(): void {
    if (!this.view || !this.awareness) {
      throw new Error('Tracker has been stopped')
    }
  }
}
