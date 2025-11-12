/**
 * AgentQueryAdapter
 *
 * Map-based implementation for tracking agent queries.
 * Implements IAgentQueryAdapter interface.
 */

import { IAgentQueryAdapter } from '../../application/interfaces/agent-query-adapter'
import { AgentQuery } from '../../domain/entities/agent-query'
import { QueryId } from '../../domain/value-objects/query-id'
import { NodeId } from '../../domain/value-objects/node-id'

export class AgentQueryAdapter implements IAgentQueryAdapter {
  private queries: Map<string, AgentQuery>
  private nodeIdIndex: Map<string, string>

  constructor() {
    this.queries = new Map()
    this.nodeIdIndex = new Map()
  }

  add(query: AgentQuery): void {
    this.queries.set(query.queryId.value, query)
    this.nodeIdIndex.set(query.nodeId.value, query.queryId.value)
  }

  get(queryId: QueryId): AgentQuery | undefined {
    return this.queries.get(queryId.value)
  }

  getByNodeId(nodeId: NodeId): AgentQuery | undefined {
    const queryIdValue = this.nodeIdIndex.get(nodeId.value)
    if (!queryIdValue) return undefined
    return this.queries.get(queryIdValue)
  }

  update(query: AgentQuery): void {
    if (this.queries.has(query.queryId.value)) {
      this.queries.set(query.queryId.value, query)
    }
  }

  remove(queryId: QueryId): void {
    const query = this.queries.get(queryId.value)
    if (query) {
      this.nodeIdIndex.delete(query.nodeId.value)
      this.queries.delete(queryId.value)
    }
  }

  getActiveQueries(): AgentQuery[] {
    return Array.from(this.queries.values())
  }

  has(queryId: QueryId): boolean {
    return this.queries.has(queryId.value)
  }
}
