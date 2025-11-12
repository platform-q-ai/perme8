/**
 * MilkdownSerializerAdapter - Infrastructure Layer
 *
 * Wraps Milkdown serializer for converting ProseMirror documents to Markdown.
 * This adapter provides a clean interface for markdown serialization,
 * abstracting away Milkdown-specific serializer complexity.
 *
 * Infrastructure Layer Characteristics:
 * - Wraps external library (Milkdown serializer) behind clean interface
 * - Converts ProseMirror Node → Markdown string
 * - Handles serialization of documents and selections
 * - Provides graceful error handling
 *
 * SOLID Principles:
 * - Single Responsibility: Handles markdown serialization only
 * - Dependency Inversion: Depends on Milkdown context abstraction
 *
 * @module infrastructure/milkdown
 */

import { serializerCtx } from '@milkdown/core'
import type { Ctx } from '@milkdown/ctx'
import type { Node } from 'prosemirror-model'
import type { EditorState } from 'prosemirror-state'

/**
 * Milkdown Serializer adapter
 *
 * Wraps Milkdown serializer for converting ProseMirror to Markdown.
 * Provides methods to serialize full documents or just current selection.
 *
 * Usage:
 * ```typescript
 * editor.action((ctx) => {
 *   const serializer = new MilkdownSerializerAdapter(ctx)
 *   const markdown = serializer.serialize(editorView.state.doc)
 * })
 * ```
 */
export class MilkdownSerializerAdapter {
  private ctx: Ctx

  /**
   * Creates a new MilkdownSerializerAdapter
   *
   * @param ctx - Milkdown context providing access to serializer
   */
  constructor(ctx: Ctx) {
    this.ctx = ctx
  }

  /**
   * Serialize ProseMirror document to markdown
   *
   * Converts a ProseMirror Node (usually the full document) to markdown string.
   * Handles errors gracefully by returning empty string.
   *
   * @param doc - ProseMirror document node to serialize
   * @returns Markdown string representation
   */
  serialize(doc: Node): string {
    try {
      // Get serializer from Milkdown context
      const serializer = this.ctx.get(serializerCtx)

      // Convert ProseMirror doc to markdown
      const markdown = serializer(doc)

      return markdown || ''
    } catch (error) {
      console.error('Error serializing document:', error)
      return ''
    }
  }

  /**
   * Serialize current selection to markdown
   *
   * Extracts the selected content from editor state and converts it to markdown.
   * Returns empty string for empty/collapsed selections.
   *
   * @param state - Editor state containing selection
   * @returns Markdown string of selected content
   */
  serializeSelection(state: EditorState): string {
    try {
      // Handle empty selection (collapsed cursor)
      if (state.selection.from === state.selection.to) {
        return ''
      }

      // Extract selection content
      const { from, to } = state.selection
      const selectedFragment = state.doc.cut(from, to)

      // Serialize the selection fragment
      return this.serialize(selectedFragment as any)
    } catch (error) {
      console.error('Error serializing selection:', error)
      return ''
    }
  }
}
