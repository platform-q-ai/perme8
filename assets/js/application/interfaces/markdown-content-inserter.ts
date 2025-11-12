/**
 * IMarkdownContentInserter
 *
 * Interface for inserting markdown content into the editor.
 * Abstracts ProseMirror-specific details from the application layer.
 */

export interface IMarkdownContentInserter {
  /**
   * Insert markdown content at the current cursor position
   * Parses markdown and inserts as ProseMirror nodes
   */
  insertMarkdown(markdown: string): void
}
