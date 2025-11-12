/**
 * IMarkdownParserAdapter
 *
 * Interface for parsing markdown into ProseMirror nodes.
 * Abstracts Milkdown-specific details from the application layer.
 */

import { Node as ProseMirrorNode } from '@milkdown/prose/model'

/**
 * Result of parsing markdown
 */
export interface ParsedDocument {
  /** Parsed ProseMirror nodes from the markdown */
  content: ProseMirrorNode[]
}

export interface IMarkdownParserAdapter {
  /**
   * Parse markdown text into ProseMirror nodes
   * Returns the parsed content or null on error
   */
  parse(markdown: string): ParsedDocument | null
}
