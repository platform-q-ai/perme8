/**
 * AgentAssistantOrchestrator
 *
 * Orchestrates all agent assistant functionality.
 * Coordinates use cases in response to events.
 *
 * This is the entry point for the agent assistant feature,
 * connecting the UI layer (hooks/plugins) with the application logic.
 */

import { DetectAgentMention } from '../use-cases/detect-agent-mention'
import { TriggerAgentQuery } from '../use-cases/trigger-agent-query'
import { HandleAgentChunk } from '../use-cases/handle-agent-chunk'
import { HandleAgentCompletion } from '../use-cases/handle-agent-completion'
import { HandleAgentError } from '../use-cases/handle-agent-error'
import { logger } from '../../infrastructure/browser/logger'

export class AgentAssistantOrchestrator {
  constructor(
    private readonly detectMention: DetectAgentMention,
    private readonly triggerQuery: TriggerAgentQuery,
    private readonly handleChunk: HandleAgentChunk,
    private readonly handleCompletion: HandleAgentCompletion,
    private readonly handleError: HandleAgentError
  ) {}

  /**
   * Handle Enter key press
   * Returns true if mention was handled, false otherwise
   */
  onEnterKey(): boolean {
    try {
      // Detect mention at cursor
      const detection = this.detectMention.execute()
      if (!detection) {
        return false
      }

      // Extract question
      const question = this.detectMention.extractQuestion()
      if (!question) {
        return false
      }

      // Trigger query
      this.triggerQuery.execute(detection, question)
      return true
    } catch (error) {
      logger.error('AgentAssistantOrchestrator', 'Error handling Enter key', error)
      // Return false to allow default behavior (e.g., inserting newline)
      return false
    }
  }

  /**
   * Handle chunk event from server
   */
  onChunk(payload: { node_id: string; chunk: string }): void {
    this.handleChunk.execute({ nodeId: payload.node_id, chunk: payload.chunk })
  }

  /**
   * Handle completion event from server
   */
  onDone(payload: { node_id: string; response: string }): void {
    this.handleCompletion.execute({ nodeId: payload.node_id, response: payload.response })
  }

  /**
   * Handle error event from server
   */
  onError(payload: { node_id: string; error?: string }): void {
    const error = payload.error || 'An unknown error occurred'
    this.handleError.execute({ nodeId: payload.node_id, error })
  }
}
