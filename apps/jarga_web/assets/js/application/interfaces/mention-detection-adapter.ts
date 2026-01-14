/**
 * IMentionDetectionAdapter
 *
 * Interface for detecting mentions in the editor.
 * Abstracts ProseMirror-specific details from the application layer.
 */

import { MentionDetection } from '../../domain/policies/mention-detection-policy'

export interface IMentionDetectionAdapter {
  /**
   * Detect mention at current cursor position
   * Returns null if no mention found
   */
  detectAtCursor(): MentionDetection | null

  /**
   * Check if cursor is within a mention
   */
  hasMentionAtCursor(): boolean
}
