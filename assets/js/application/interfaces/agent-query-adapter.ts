/**
 * IAgentQueryAdapter
 *
 * Interface for tracking agent queries in the infrastructure layer.
 * Allows the application layer to manage query state without depending on ProseMirror.
 */

import { AgentQuery } from '../../domain/entities/agent-query'
import { QueryId } from '../../domain/value-objects/query-id'
import { NodeId } from '../../domain/value-objects/node-id'

export interface IAgentQueryAdapter {
  /**
   * Add a query to tracking
   */
  add(query: AgentQuery): void

  /**
   * Get a query by its query ID
   */
  get(queryId: QueryId): AgentQuery | undefined

  /**
   * Get a query by its node ID
   */
  getByNodeId(nodeId: NodeId): AgentQuery | undefined

  /**
   * Update a query
   */
  update(query: AgentQuery): void

  /**
   * Remove a query from tracking
   */
  remove(queryId: QueryId): void

  /**
   * Get all active queries
   */
  getActiveQueries(): AgentQuery[]

  /**
   * Check if a query exists
   */
  has(queryId: QueryId): boolean
}
