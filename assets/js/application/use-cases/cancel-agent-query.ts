/**
 * CancelAgentQuery Use Case
 *
 * Orchestrates canceling an active AI agent query.
 * This use case validates the query ID and pushes a cancellation event
 * to the server via LiveView.
 *
 * Dependencies (injected):
 * - LiveViewBridge: For server communication
 *
 * @module application/use-cases
 */

import type { LiveViewBridge } from '../interfaces/liveview-bridge.interface'

/**
 * Use case for canceling an agent query
 *
 * Responsibilities:
 * - Validate query ID is not empty
 * - Push cancel event to server
 * - Handle server communication errors
 *
 * Business Logic:
 * - Query ID must be non-empty string
 * - Cancellation is idempotent (can cancel same query multiple times)
 * - Query ID is sent exactly as provided (no modification)
 */
export class CancelAgentQuery {
  /**
   * Creates a new CancelAgentQuery use case
   *
   * @param bridge - LiveView bridge for server communication
   */
  constructor(private readonly bridge: LiveViewBridge) {}

  /**
   * Execute the agent query cancellation
   *
   * @param queryId - Unique query identifier to cancel
   * @returns Promise that resolves when cancellation is sent
   * @throws {Error} If query ID is empty
   *
   * @example
   * ```typescript
   * await useCase.execute('query-123')
   * console.log('Cancellation sent to server')
   * ```
   */
  async execute(queryId: string): Promise<void> {
    // Validate query ID
    this.validateQueryId(queryId)

    // Push cancel event to server
    await this.bridge.pushEvent('agent_cancel', {
      node_id: queryId
    })
  }

  /**
   * Validates query ID is not empty
   * @private
   */
  private validateQueryId(queryId: string): void {
    if (!queryId || queryId.trim() === '') {
      throw new Error('Query ID cannot be empty')
    }
  }
}
