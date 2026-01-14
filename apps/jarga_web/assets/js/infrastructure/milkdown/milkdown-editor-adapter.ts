/**
 * MilkdownEditorAdapter - Infrastructure Layer
 *
 * Wraps Milkdown Editor to provide lifecycle management and context operations.
 * This adapter provides a clean interface for creating and managing Milkdown editors,
 * abstracting away Milkdown-specific complexity.
 *
 * Infrastructure Layer Characteristics:
 * - Wraps external library (Milkdown) behind clean interface
 * - Manages editor lifecycle (create, action, destroy)
 * - Provides access to underlying ProseMirror EditorView
 * - Handles Milkdown context (Ctx) operations
 *
 * SOLID Principles:
 * - Single Responsibility: Manages Milkdown editor lifecycle only
 * - Open/Closed: Extensible through plugin system
 * - Dependency Inversion: Depends on Milkdown abstractions (Editor, Ctx)
 *
 * @module infrastructure/milkdown
 */

import { Editor, rootCtx, editorViewCtx } from '@milkdown/core'
import type { Ctx } from '@milkdown/ctx'
import type { EditorView } from 'prosemirror-view'

/**
 * Milkdown Editor adapter
 *
 * Wraps Milkdown Editor for lifecycle management and context access.
 * Provides methods to create editor, get view, execute actions, and clean up.
 *
 * Usage:
 * ```typescript
 * const adapter = new MilkdownEditorAdapter(element)
 * await adapter.create([commonmark, gfm, ...plugins])
 * const view = adapter.getEditorView()
 * adapter.action((ctx) => { ... })
 * adapter.destroy()
 * ```
 *
 * Note: Tests use mocks for Editor as it's complex to instantiate.
 */
export class MilkdownEditorAdapter {
  private readonly element: HTMLElement
  private editor: Editor | null = null
  private destroyed: boolean = false

  /**
   * Creates a new MilkdownEditorAdapter
   *
   * @param element - DOM element to mount the editor
   */
  constructor(element: HTMLElement) {
    this.element = element
  }

  /**
   * Create Milkdown editor with plugins
   *
   * Initializes the Milkdown editor with provided plugins and mounts it to the DOM element.
   * This method should be called once. Calling it multiple times is a no-op.
   *
   * @param plugins - Array of Milkdown plugins to use
   * @returns Promise that resolves when editor is created
   * @throws {Error} If adapter has been destroyed
   */
  async create(plugins: any[]): Promise<void> {
    if (this.destroyed) {
      throw new Error('Adapter has been destroyed')
    }

    if (this.editor) {
      return // Already created (idempotent)
    }

    try {
      const editor = Editor.make()
        .config((ctx) => ctx.set(rootCtx, this.element))

      for (const plugin of plugins) {
        editor.use(plugin)
      }

      await editor.create()
      this.editor = editor
    } catch (error) {
      console.error('Error creating Milkdown editor:', error)
      throw error
    }
  }

  /**
   * Get underlying ProseMirror EditorView
   *
   * Extracts the ProseMirror EditorView from Milkdown context.
   * Returns null if editor is not created, destroyed, or view is not available.
   *
   * @returns EditorView or null if not available
   */
  getEditorView(): EditorView | null {
    if (this.destroyed || !this.editor) {
      return null
    }

    try {
      let view: EditorView | null = null

      this.editor.action((ctx) => {
        view = ctx.get(editorViewCtx)
      })

      return view
    } catch (error) {
      console.error('Error getting EditorView:', error)
      return null
    }
  }

  /**
   * Execute action with Milkdown context
   *
   * Runs a callback with access to the Milkdown context (Ctx).
   * The context provides access to editor services like view, parser, serializer.
   *
   * This is the primary way to interact with the Milkdown editor's internal state.
   *
   * @param callback - Function to execute with Milkdown context
   */
  action(callback: (ctx: Ctx) => void): void {
    if (this.destroyed || !this.editor) {
      // Silently ignore if editor not ready or destroyed (graceful degradation)
      return
    }

    try {
      this.editor.action(callback)
    } catch (error) {
      console.error('Error executing editor action:', error)
      // Don't rethrow - graceful degradation for UI operations
    }
  }

  /**
   * Clean up resources
   *
   * Destroys the Milkdown editor and clears all references.
   * This method is idempotent - calling it multiple times is safe.
   * After calling destroy(), the adapter should not be used.
   */
  destroy(): void {
    if (this.destroyed) {
      return // Already destroyed (idempotent)
    }

    this.destroyed = true

    // Destroy editor if it exists
    if (this.editor) {
      try {
        this.editor.destroy()
      } catch (error) {
        console.error('Error destroying Milkdown editor:', error)
        // Continue cleanup despite error
      }

      this.editor = null
    }
  }
}

