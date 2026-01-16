/**
 * MentionDetectionPolicy
 *
 * Domain policy for detecting agent mentions in text.
 * Pure business logic with no external dependencies.
 *
 * Responsibilities:
 * - Detect mentions at cursor position
 * - Extract questions from mentions
 * - Validate mentions for querying
 */

import { MentionPattern } from '../value-objects/mention-pattern'

export interface MentionDetection {
  from: number
  to: number
  text: string
}

export class MentionDetectionPolicy {
  constructor(public readonly pattern: MentionPattern) {}

  /**
   * Detect mention at cursor position in text
   * Returns null if no mention found at cursor
   */
  detectAtCursor(text: string, cursorPos: number): MentionDetection | null {
    return this.pattern.findInText(text, cursorPos)
  }

  /**
   * Extract question from detected mention
   * Returns null if no question found or question is empty
   */
  extractQuestion(detection: MentionDetection | null): string | null {
    if (!detection) {
      return null
    }

    return this.pattern.extract(detection.text)
  }

  /**
   * Check if detected mention is valid for querying
   * A mention is valid if it has a non-empty question
   */
  isValidForQuery(detection: MentionDetection | null): boolean {
    if (!detection) {
      return false
    }

    const question = this.extractQuestion(detection)
    return question !== null && question.trim().length > 0
  }
}
