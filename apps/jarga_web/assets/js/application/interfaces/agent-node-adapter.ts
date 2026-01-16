/**
 * IAgentNodeAdapter
 *
 * Interface for manipulating agent response nodes in the editor.
 * Abstracts ProseMirror-specific details from the application layer.
 */

import { NodeId } from '../../domain/value-objects/node-id'
import { AgentResponse } from '../../domain/entities/agent-response'
import { MentionDetection } from '../../domain/policies/mention-detection-policy'

export interface IAgentNodeAdapter {
  /**
   * Create an agent response node and insert it in place of the mention
   * Returns the node ID of the created node
   */
  createAndInsert(mention: MentionDetection, nodeId: NodeId): void

  /**
   * Update an agent response node's attributes
   */
  update(response: AgentResponse): void

  /**
   * Append a chunk to an agent response node
   */
  appendChunk(nodeId: NodeId, chunk: string): void

  /**
   * Replace agent response node with parsed markdown content
   */
  replaceWithMarkdown(nodeId: NodeId, markdown: string): void

  /**
   * Check if a node exists
   */
  exists(nodeId: NodeId): boolean
}
