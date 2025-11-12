/**
 * HandleAgentCompletion Use Case
 *
 * Handles completion of an agent query.
 * Replaces the streaming node with parsed markdown and marks query as completed.
 */

import { NodeId } from '../../domain/value-objects/node-id'
import { IAgentQueryAdapter } from '../interfaces/agent-query-adapter'
import { IAgentNodeAdapter } from '../interfaces/agent-node-adapter'

export interface HandleAgentCompletionInput {
  nodeId: string
  response: string
}

export class HandleAgentCompletion {
  constructor(
    private readonly queryAdapter: IAgentQueryAdapter,
    private readonly nodeAdapter: IAgentNodeAdapter
  ) {}

  /**
   * Execute the use case
   * Replaces node with markdown and marks query as completed
   */
  execute(input: HandleAgentCompletionInput): void {
    const nodeId = new NodeId(input.nodeId)

    // Find the query
    const query = this.queryAdapter.getByNodeId(nodeId)
    if (!query) {
      console.warn('[HandleAgentCompletion] Query not found for nodeId:', input.nodeId)
      return
    }

    // Replace node with parsed markdown
    this.nodeAdapter.replaceWithMarkdown(nodeId, input.response)

    // Mark query as completed
    const completed = query.markAsCompleted(input.response)
    this.queryAdapter.update(completed)
  }
}
