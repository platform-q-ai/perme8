/**
 * AgentQuery Entity
 *
 * Represents an agent query in the domain layer - pure business logic.
 * Tracks the lifecycle of a question asked to the AI agent.
 *
 * Responsibilities:
 * - Manage query state transitions (pending → streaming → completed/failed)
 * - Track timing information
 * - Validate state transitions
 * - Calculate query duration
 */

import { QueryId } from '../value-objects/query-id'
import { NodeId } from '../value-objects/node-id'

export type AgentQueryStatus = 'pending' | 'streaming' | 'completed' | 'failed'

export class AgentQuery {
  constructor(
    public readonly queryId: QueryId,
    public readonly nodeId: NodeId,
    public readonly question: string,
    public readonly status: AgentQueryStatus = 'pending',
    public readonly startTime: Date = new Date(),
    public readonly endTime?: Date,
    public readonly response?: string,
    public readonly error?: string
  ) {
    if (!question || question.trim().length === 0) {
      throw new Error('Question cannot be empty')
    }
  }

  /**
   * Create a new query with generated IDs
   */
  static create(question: string): AgentQuery {
    const queryId = QueryId.generate()
    const nodeId = NodeId.generate()
    return new AgentQuery(queryId, nodeId, question)
  }

  /**
   * Create a new query with a specific node ID (e.g., from legacy system)
   */
  static createWithNodeId(nodeId: NodeId, question: string): AgentQuery {
    const queryId = QueryId.generate()
    return new AgentQuery(queryId, nodeId, question)
  }

  /**
   * Mark query as streaming
   */
  markAsStreaming(): AgentQuery {
    if (this.status !== 'pending') {
      throw new Error('Can only mark pending queries as streaming')
    }

    return new AgentQuery(
      this.queryId,
      this.nodeId,
      this.question,
      'streaming',
      this.startTime
    )
  }

  /**
   * Mark query as completed with response
   */
  markAsCompleted(response: string): AgentQuery {
    if (this.status !== 'streaming') {
      throw new Error('Can only mark streaming queries as completed')
    }

    if (!response || response.trim().length === 0) {
      throw new Error('Response cannot be empty')
    }

    return new AgentQuery(
      this.queryId,
      this.nodeId,
      this.question,
      'completed',
      this.startTime,
      new Date(),
      response
    )
  }

  /**
   * Mark query as failed with error
   */
  markAsFailed(error: string): AgentQuery {
    if (!error || error.trim().length === 0) {
      throw new Error('Error message cannot be empty')
    }

    return new AgentQuery(
      this.queryId,
      this.nodeId,
      this.question,
      'failed',
      this.startTime,
      new Date(),
      undefined,
      error
    )
  }

  /**
   * Get query duration in milliseconds
   * Returns null if query has not ended
   */
  getDuration(): number | null {
    if (!this.endTime) {
      return null
    }

    return this.endTime.getTime() - this.startTime.getTime()
  }

  /**
   * Check if query is active (pending or streaming)
   */
  isActive(): boolean {
    return this.status === 'pending' || this.status === 'streaming'
  }
}
