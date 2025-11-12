/**
 * HandleAgentError Use Case
 *
 * Handles an error from an agent query.
 * Updates the node to error state and marks query as failed.
 */

import { NodeId } from '../../domain/value-objects/node-id'
import { AgentResponse } from '../../domain/entities/agent-response'
import { IAgentQueryAdapter } from '../interfaces/agent-query-adapter'
import { IAgentNodeAdapter } from '../interfaces/agent-node-adapter'

export interface HandleAgentErrorInput {
  nodeId: string
  error: string
}

export class HandleAgentError {
  constructor(
    private readonly queryAdapter: IAgentQueryAdapter,
    private readonly nodeAdapter: IAgentNodeAdapter
  ) {}

  /**
   * Execute the use case
   * Updates node to error state and marks query as failed
   */
  execute(input: HandleAgentErrorInput): void {
    const nodeId = new NodeId(input.nodeId)

    // Find the query
    const query = this.queryAdapter.getByNodeId(nodeId)
    if (!query) {
      return
    }

    // Update node to error state
    const response = AgentResponse.create(nodeId)
    const errorResponse = response.markAsError(input.error)
    this.nodeAdapter.update(errorResponse)

    // Mark query as failed
    const failed = query.markAsFailed(input.error)
    this.queryAdapter.update(failed)
  }
}
