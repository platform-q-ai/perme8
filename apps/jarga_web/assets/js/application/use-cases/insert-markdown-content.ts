/**
 * InsertMarkdownContent Use Case
 *
 * Inserts markdown content into the editor at the cursor position.
 * Parses markdown into ProseMirror nodes for proper structure.
 *
 * This use case reuses the same markdown parsing logic as agent responses.
 */

import type { IMarkdownContentInserter } from '../interfaces/markdown-content-inserter'

export interface InsertMarkdownContentInput {
  markdown: string
}

export class InsertMarkdownContent {
  constructor(private readonly inserter: IMarkdownContentInserter) {}

  /**
   * Execute the use case
   * Parses markdown and inserts nodes at cursor position
   */
  execute(input: InsertMarkdownContentInput): void {
    const { markdown } = input

    // Validate input
    if (!markdown || markdown.trim().length === 0) {
      console.warn('[InsertMarkdownContent] Empty markdown, skipping insertion')
      return
    }

    // Delegate to infrastructure adapter
    this.inserter.insertMarkdown(markdown)
  }
}
