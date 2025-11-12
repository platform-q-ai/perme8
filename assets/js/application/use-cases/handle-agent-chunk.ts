/**
 * HandleAgentChunk Use Case
 *
 * Handles a streaming chunk from the AI agent.
 * Marks query as streaming (if pending) and appends the chunk to the node.
 */

import { NodeId } from '../../domain/value-objects/node-id'
import { IAgentNodeAdapter } from '../interfaces/agent-node-adapter'
import { IAgentQueryAdapter } from '../interfaces/agent-query-adapter'

export interface HandleAgentChunkInput {
  nodeId: string
  chunk: string
}

export class HandleAgentChunk {
  constructor(
    private readonly nodeAdapter: IAgentNodeAdapter,
    private readonly queryAdapter: IAgentQueryAdapter
  ) {}

  /**
   * Execute the use case
   * Marks query as streaming (if pending) and appends chunk to the node
   */
  execute(input: HandleAgentChunkInput): void {
    const nodeId = new NodeId(input.nodeId)

    // Find the query and mark as streaming if it's still pending
    const query = this.queryAdapter.getByNodeId(nodeId)
    if (query && query.status === 'pending') {
      const streaming = query.markAsStreaming()
      this.queryAdapter.update(streaming)
    }

    // Append chunk to the node
    this.nodeAdapter.appendChunk(nodeId, input.chunk)
  }
}
