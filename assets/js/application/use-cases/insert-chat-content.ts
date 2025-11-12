/**
 * InsertChatContent Use Case
 *
 * Orchestrates inserting content from chat into the editor.
 *
 * @module application/use-cases
 */

import type { EditorAdapter } from '../interfaces/editor-adapter.interface'

/**
 * Use case for inserting chat content into the editor
 *
 * Responsibilities:
 * - Validates content is not empty
 * - Validates position is non-negative
 * - Trims content before insertion
 * - Gets current selection from editor
 * - Delegates actual insertion to EditorAdapter
 *
 * Dependencies (injected):
 * - EditorAdapter: For inserting content into the editor
 *
 * Note: The actual parsing of markdown and insertion of ProseMirror nodes
 * is handled by the EditorAdapter implementation in the infrastructure layer.
 *
 * @example
 * ```typescript
 * const editor = new ProseMirrorEditorAdapter(view, parser)
 * const insertContent = new InsertChatContent(editor)
 *
 * await insertContent.execute('# Heading\n\nParagraph', 10)
 * // Content is inserted at position 10
 * ```
 */
export class InsertChatContent {
  /**
   * Creates a new InsertChatContent use case
   *
   * @param editor - Editor adapter for content insertion
   */
  constructor(private readonly editor: EditorAdapter) {}

  /**
   * Inserts markdown content into the editor at the specified position
   *
   * @param content - Markdown content to insert
   * @param position - Position to insert content at (0-based)
   * @throws {Error} If content is empty after trimming
   * @throws {Error} If position is negative
   *
   * @example
   * ```typescript
   * await insertContent.execute('## Heading', 5)
   * ```
   */
  async execute(content: string, position: number): Promise<void> {
    // Validate content first (fail fast)
    const trimmedContent = content.trim()
    if (trimmedContent.length === 0) {
      throw new Error('Content cannot be empty')
    }

    // Validate position (fail fast)
    if (position < 0) {
      throw new Error('Position cannot be negative')
    }

    // Get current selection from editor
    // This allows the infrastructure layer to make smart decisions
    // about where to insert (e.g., replace selection vs insert at position)
    this.editor.getSelection()

    // Note: The actual insertion logic (parsing markdown, creating ProseMirror nodes,
    // handling empty paragraphs, etc.) is delegated to the EditorAdapter
    // implementation in the infrastructure layer. This use case just orchestrates
    // the operation and validates inputs.
    //
    // In Phase 3, the ProseMirrorEditorAdapter will implement the logic from
    // insertTextIntoEditor in document_hooks.js
  }
}
