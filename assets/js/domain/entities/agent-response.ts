/**
 * AgentResponse Entity
 *
 * Represents an agent response node in the domain layer - pure business logic.
 * Manages the state and content of an AI agent's response as it streams in.
 *
 * Responsibilities:
 * - Track response state (streaming, error)
 * - Manage response content accumulation
 * - Handle error states
 * - Provide immutable updates
 */

import { NodeId } from '../value-objects/node-id'

export type AgentResponseState = 'streaming' | 'error'

export class AgentResponse {
  constructor(
    public readonly nodeId: NodeId,
    public readonly state: AgentResponseState = 'streaming',
    public readonly content: string = '',
    public readonly error: string = ''
  ) {}

  /**
   * Create a new agent response in streaming state
   */
  static create(nodeId: NodeId): AgentResponse {
    return new AgentResponse(nodeId, 'streaming', '', '')
  }

  /**
   * Append a chunk of text to the response content
   */
  appendChunk(chunk: string): AgentResponse {
    if (this.state !== 'streaming') {
      throw new Error('Can only append chunks to streaming responses')
    }

    return new AgentResponse(
      this.nodeId,
      this.state,
      this.content + chunk,
      this.error
    )
  }

  /**
   * Mark response as error with message
   */
  markAsError(errorMessage: string): AgentResponse {
    if (!errorMessage || errorMessage.trim().length === 0) {
      throw new Error('Error message cannot be empty')
    }

    return new AgentResponse(
      this.nodeId,
      'error',
      '', // Clear content on error
      errorMessage
    )
  }

  /**
   * Update attributes (generic update method)
   */
  updateAttributes(updates: {
    state?: AgentResponseState
    content?: string
    error?: string
  }): AgentResponse {
    return new AgentResponse(
      this.nodeId,
      updates.state ?? this.state,
      updates.content ?? this.content,
      updates.error ?? this.error
    )
  }

  /**
   * Check if response is currently streaming
   */
  isStreaming(): boolean {
    return this.state === 'streaming'
  }

  /**
   * Check if response has an error
   */
  hasError(): boolean {
    return this.state === 'error'
  }

  /**
   * Check if response has content
   */
  hasContent(): boolean {
    return this.content.trim().length > 0
  }
}
