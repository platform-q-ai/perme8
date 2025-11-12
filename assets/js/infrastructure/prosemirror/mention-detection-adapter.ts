/**
 * MentionDetectionAdapter
 *
 * ProseMirror-based implementation for detecting @j mentions at cursor position.
 * Implements IMentionDetectionAdapter interface.
 */

import { IMentionDetectionAdapter } from '../../application/interfaces/mention-detection-adapter'
import { MentionDetection } from '../../domain/policies/mention-detection-policy'
import { EditorView } from '@milkdown/prose/view'

const MENTION_REGEX = /@j\s+(.+)/i

export class MentionDetectionAdapter implements IMentionDetectionAdapter {
  constructor(private view: EditorView) {}

  detectAtCursor(): MentionDetection | null {
    const { state } = this.view
    const { $from } = state.selection

    const mention = this.findMentionAtCursor($from)
    if (!mention) return null

    const question = this.extractQuestion(mention.text)
    if (!question || question.trim().length === 0) return null

    return {
      text: mention.text,
      from: mention.from,
      to: mention.to
    }
  }

  hasMentionAtCursor(): boolean {
    return this.detectAtCursor() !== null
  }

  private findMentionAtCursor($pos: any): { from: number; to: number; text: string } | null {
    const { parent, parentOffset } = $pos

    if (parent.type.name !== 'paragraph') return null

    const text = parent.textContent
    const matches: Array<{ from: number; to: number; text: string }> = []
    const regex = new RegExp(MENTION_REGEX, 'gi')
    let match

    while ((match = regex.exec(text)) !== null) {
      matches.push({
        from: match.index,
        to: match.index + match[0].length,
        text: match[0]
      })
    }

    for (const mention of matches) {
      if (parentOffset >= mention.from && parentOffset <= mention.to) {
        const nodeStart = $pos.start()
        return {
          from: nodeStart + mention.from,
          to: nodeStart + mention.to,
          text: mention.text
        }
      }
    }

    return null
  }

  private extractQuestion(text: string): string {
    const match = text.match(MENTION_REGEX)
    return match ? match[1].trim() : ''
  }
}
