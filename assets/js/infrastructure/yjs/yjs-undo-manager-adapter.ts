/**
 * YjsUndoManagerAdapter - Infrastructure Layer
 *
 * Wraps Yjs Y.UndoManager for undo/redo operations in collaborative editing.
 * This adapter provides a clean interface for undo/redo functionality that tracks
 * only local changes (not remote changes).
 *
 * Infrastructure Layer Characteristics:
 * - Wraps external library (Yjs Y.UndoManager) behind clean interface
 * - Manages undo/redo stacks for local changes only
 * - Handles Yjs-specific details (trackedOrigins, transactions)
 * - Provides resource cleanup via destroy()
 *
 * Key Behavior:
 * - Only tracks changes made with specific origin (binding object)
 * - Remote changes (different origin) are not tracked
 * - Per-client undo/redo (each user has their own undo stack)
 *
 * @module infrastructure/yjs
 */

import * as Y from 'yjs'

/**
 * Yjs implementation of undo/redo manager
 *
 * Wraps Y.UndoManager to provide undo/redo operations for collaborative editing.
 * Tracks only local changes (identified by binding object as origin).
 */
export class YjsUndoManagerAdapter {
  private undoManager: Y.UndoManager
  private destroyed: boolean = false

  /**
   * Creates a new YjsUndoManagerAdapter
   *
   * @param yXmlFragment - The Y.XmlFragment to track for undo/redo
   * @param binding - The binding object used as origin for local changes
   * @param options - Optional configuration for the undo manager
   * @throws Error if yXmlFragment or binding is null/undefined
   */
  constructor(
    yXmlFragment: Y.XmlFragment,
    binding: any,
    options: { captureTimeout?: number } = {}
  ) {
    if (!yXmlFragment) {
      throw new Error('Y.XmlFragment is required')
    }

    if (!binding) {
      throw new Error('Binding object is required')
    }

    // Create UndoManager that only tracks changes with binding as origin
    this.undoManager = new Y.UndoManager(yXmlFragment, {
      trackedOrigins: new Set([binding]),
      captureTimeout: options.captureTimeout || 0 // Default to 0 for immediate capture
    })
  }

  /**
   * Undo the last local change
   *
   * Reverts the most recent change that was made with the tracked origin.
   * Does nothing if undo stack is empty.
   */
  undo(): void {
    if (this.destroyed) {
      return
    }

    this.undoManager.undo()
  }

  /**
   * Redo the last undone change
   *
   * Re-applies the most recently undone change.
   * Does nothing if redo stack is empty.
   */
  redo(): void {
    if (this.destroyed) {
      return
    }

    this.undoManager.redo()
  }

  /**
   * Check if undo is available
   *
   * @returns true if there are changes that can be undone
   */
  canUndo(): boolean {
    if (this.destroyed) {
      return false
    }

    return this.undoManager.canUndo()
  }

  /**
   * Check if redo is available
   *
   * @returns true if there are changes that can be redone
   */
  canRedo(): boolean {
    if (this.destroyed) {
      return false
    }

    return this.undoManager.canRedo()
  }

  /**
   * Clear undo and redo stacks
   *
   * Removes all tracked changes from both undo and redo stacks.
   * After calling clear(), canUndo() and canRedo() will return false.
   */
  clear(): void {
    if (this.destroyed) {
      return
    }

    this.undoManager.clear()
  }

  /**
   * Clean up resources
   *
   * Stops tracking changes and destroys the undo manager.
   * After calling destroy(), the adapter should not be used.
   */
  destroy(): void {
    if (this.destroyed) return

    this.destroyed = true

    // Stop tracking changes
    this.undoManager.destroy()
  }
}
