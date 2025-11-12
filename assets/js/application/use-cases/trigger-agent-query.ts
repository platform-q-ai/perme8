/**
 * TriggerAgentQuery Use Case
 *
 * Triggers an agent query by creating the query entity, inserting the response node,
 * and sending the query to the server.
 */

import { AgentQuery } from '../../domain/entities/agent-query'
import { MentionDetection } from '../../domain/policies/mention-detection-policy'
import { IAgentQueryAdapter } from '../interfaces/agent-query-adapter'
import { IAgentNodeAdapter } from '../interfaces/agent-node-adapter'
import { ILiveViewEventAdapter } from '../interfaces/liveview-event-adapter'

export class TriggerAgentQuery {
  constructor(
    private readonly queryAdapter: IAgentQueryAdapter,
    private readonly nodeAdapter: IAgentNodeAdapter,
    private readonly eventAdapter: ILiveViewEventAdapter
  ) {}

  /**
   * Execute the use case
   * Creates query, inserts node, and pushes event to server
   */
  execute(mention: MentionDetection, question: string): AgentQuery {
    // Create domain entity
    const query = AgentQuery.create(question)

    // Track query
    this.queryAdapter.add(query)

    // Create and insert agent response node
    this.nodeAdapter.createAndInsert(mention, query.nodeId)

    // Send query to LiveView server
    this.eventAdapter.pushEvent('agent_query', {
      question,
      node_id: query.nodeId.value
    })

    return query
  }
}
