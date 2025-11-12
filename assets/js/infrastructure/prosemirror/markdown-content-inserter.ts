/**
 * MarkdownContentInserter
 *
 * ProseMirror-based implementation for inserting markdown content.
 * Reuses the same markdown parsing logic as agent responses.
 */

import { IMarkdownContentInserter } from '../../application/interfaces/markdown-content-inserter'
import { IMarkdownParserAdapter } from '../../application/interfaces/markdown-parser-adapter'
import { EditorView } from '@milkdown/prose/view'
import { Node as ProseMirrorNode } from '@milkdown/prose/model'
import { Selection } from '@milkdown/prose/state'

export class MarkdownContentInserter implements IMarkdownContentInserter {
  constructor(
    private view: EditorView,
    private parser: IMarkdownParserAdapter
  ) {}

  insertMarkdown(markdown: string): void {
    // Parse markdown into ProseMirror nodes
    const parsed = this.parser.parse(markdown)
    if (!parsed || !parsed.content || parsed.content.length === 0) {
      console.warn('[MarkdownContentInserter] Failed to parse markdown')
      return
    }

    const { state } = this.view
    const { selection } = state
    const tr = state.tr

    // If selection is not empty, delete it first
    if (!selection.empty) {
      tr.delete(selection.from, selection.to)
    }

    // Insert parsed nodes at the cursor position
    let insertPos = selection.from
    const nodes = parsed.content

    nodes.forEach((node: ProseMirrorNode) => {
      tr.insert(insertPos, node)
      insertPos += node.nodeSize
    })

    // Dispatch transaction
    this.view.dispatch(tr)

    // Move cursor to end of inserted content and focus
    const newPos = tr.doc.resolve(insertPos)
    const newSelection = Selection.near(newPos)
    const focusTr = this.view.state.tr.setSelection(newSelection)
    this.view.dispatch(focusTr)
    this.view.focus()
  }
}
