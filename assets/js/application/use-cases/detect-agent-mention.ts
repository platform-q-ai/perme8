/**
 * DetectAgentMention Use Case
 *
 * Detects agent mentions at the current cursor position.
 * Orchestrates domain logic with infrastructure adapters.
 */

import { MentionDetectionPolicy, MentionDetection } from '../../domain/policies/mention-detection-policy'
import { IMentionDetectionAdapter } from '../interfaces/mention-detection-adapter'

export class DetectAgentMention {
  constructor(
    private readonly policy: MentionDetectionPolicy,
    private readonly adapter: IMentionDetectionAdapter
  ) {}

  /**
   * Detect mention at current cursor position
   * Returns null if no valid mention found
   */
  execute(): MentionDetection | null {
    const detection = this.adapter.detectAtCursor()

    if (!this.policy.isValidForQuery(detection)) {
      return null
    }

    return detection
  }

  /**
   * Check if there is a valid mention at cursor
   */
  hasValidMention(): boolean {
    const detection = this.adapter.detectAtCursor()
    return this.policy.isValidForQuery(detection)
  }

  /**
   * Extract question from mention at cursor
   * Returns null if no valid mention found
   */
  extractQuestion(): string | null {
    const detection = this.adapter.detectAtCursor()
    return this.policy.extractQuestion(detection)
  }
}
