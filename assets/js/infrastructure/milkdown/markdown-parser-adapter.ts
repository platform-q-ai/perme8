/**
 * MarkdownParserAdapter
 *
 * Milkdown-based markdown parser adapter.
 * Implements IMarkdownParserAdapter interface.
 */

import { IMarkdownParserAdapter, ParsedDocument } from '../../application/interfaces/markdown-parser-adapter'
import { Node as ProseMirrorNode } from '@milkdown/prose/model'

export class MarkdownParserAdapter implements IMarkdownParserAdapter {
  constructor(private parser: (markdown: string) => ProseMirrorNode | string) {}

  parse(markdown: string): ParsedDocument | null {
    try {
      const trimmed = markdown.trim()

      // Handle empty markdown
      if (trimmed.length === 0) {
        return null
      }

      const result = this.parser(trimmed)

      // Handle parser errors (returns string on error)
      if (!result || typeof result === 'string') {
        console.error('[MarkdownParser] Failed to parse markdown:', result)
        return null
      }

      // Extract content nodes from the parsed document
      const nodes: ProseMirrorNode[] = []
      if (result.content) {
        result.content.forEach((node: ProseMirrorNode) => {
          nodes.push(node)
        })
      }

      return { content: nodes }
    } catch (error) {
      console.error('[MarkdownParser] Error parsing markdown:', error)
      return null
    }
  }
}
