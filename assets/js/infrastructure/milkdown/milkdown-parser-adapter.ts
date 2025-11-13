/**
 * MilkdownParserAdapter - Infrastructure Layer
 *
 * Wraps Milkdown parser for converting Markdown to ProseMirror documents.
 * This adapter provides a clean interface for markdown parsing,
 * abstracting away Milkdown-specific parser complexity.
 *
 * Infrastructure Layer Characteristics:
 * - Wraps external library (Milkdown parser) behind clean interface
 * - Converts Markdown string → ProseMirror Node
 * - Handles parsing of full documents and inline content
 * - Provides graceful error handling
 *
 * SOLID Principles:
 * - Single Responsibility: Handles markdown parsing only
 * - Dependency Inversion: Depends on Milkdown context abstraction
 *
 * @module infrastructure/milkdown
 */

import { parserCtx } from '@milkdown/core'
import type { Ctx } from '@milkdown/ctx'
import type { Node } from 'prosemirror-model'
import { IMarkdownParserAdapter, ParsedDocument } from '../../application/interfaces/markdown-parser-adapter'

/**
 * Milkdown Parser adapter
 *
 * Wraps Milkdown parser for converting Markdown to ProseMirror.
 * Provides methods to parse full documents or inline content.
 *
 * Usage:
 * ```typescript
 * editor.action((ctx) => {
 *   const parser = new MilkdownParserAdapter(ctx)
 *   const doc = parser.parse('# Hello World')
 * })
 * ```
 */
export class MilkdownParserAdapter implements IMarkdownParserAdapter {
  private ctx: Ctx

  /**
   * Creates a new MilkdownParserAdapter
   *
   * @param ctx - Milkdown context providing access to parser
   */
  constructor(ctx: Ctx) {
    this.ctx = ctx
  }

  /**
   * Parse markdown to ProseMirror node
   *
   * Converts a markdown string to a ProseMirror Node (usually a full document).
   * Returns null for empty or whitespace-only markdown.
   * Handles errors gracefully by returning null.
   *
   * @param markdown - Markdown string to parse
   * @returns ParsedDocument with content nodes or null
   */
  parse(markdown: string): ParsedDocument | null {
    try {
      // Handle empty or whitespace-only markdown
      if (!markdown || markdown.trim().length === 0) {
        return null
      }

      // Get parser from Milkdown context
      const parser = this.ctx.get(parserCtx)

      // Convert markdown to ProseMirror node
      const node = parser(markdown)

      if (!node) {
        return null
      }

      // Extract content nodes from the parsed document
      const nodes: Node[] = []
      if (node.content) {
        node.content.forEach((childNode: Node) => {
          nodes.push(childNode)
        })
      }

      return { content: nodes }
    } catch (error) {
      console.error('Error parsing markdown:', error)
      return null
    }
  }

  /**
   * Parse inline markdown to node array
   *
   * Converts inline markdown (no block elements) to an array of ProseMirror nodes.
   * Useful for parsing user input, mentions, inline formatting, etc.
   * Returns empty array for empty markdown or on error.
   *
   * @param markdown - Inline markdown string to parse
   * @returns Array of ProseMirror nodes
   */
  parseInline(markdown: string): Node[] {
    try {
      // Handle empty or whitespace-only markdown
      if (!markdown || markdown.trim().length === 0) {
        return []
      }

      // Parse as full document first
      const parsedDoc = this.parse(markdown)

      if (!parsedDoc || !parsedDoc.content) {
        return []
      }

      // Extract inline content from first paragraph if available
      // Get content from first paragraph-like node
      const firstBlock = parsedDoc.content[0]
      if (firstBlock && firstBlock.content) {
        // ProseMirror Node.content is a Fragment, convert to array
        const nodes: Node[] = []
        firstBlock.content.forEach((node: Node) => {
          nodes.push(node)
        })
        return nodes
      }

      return []
    } catch (error) {
      console.error('Error parsing inline markdown:', error)
      return []
    }
  }
}
