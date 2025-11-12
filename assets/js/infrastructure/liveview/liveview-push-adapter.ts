/**
 * LiveViewPushAdapter
 *
 * Specialized adapter that provides type-safe wrappers around LiveViewEventBridge
 * for pushing structured events to Phoenix LiveView server.
 *
 * This adapter:
 * - Provides helper methods for common event types
 * - Validates payloads before pushing
 * - Ensures type safety for event structures
 * - Wraps generic pushEvent with domain-specific methods
 *
 * @example
 * ```typescript
 * // Create bridge and adapter
 * const bridge = new LiveViewEventBridge(this) // 'this' from Phoenix hook
 * const adapter = new LiveViewPushAdapter(bridge)
 *
 * // Push type-safe events
 * await adapter.pushYjsUpdate('update', 'state', 'user-123', '# Doc')
 * await adapter.pushAwarenessUpdate('awareness', 'user-123')
 * await adapter.pushAgentQuery('query-1', '@Agent', 'question')
 * await adapter.pushChatMessage('hello', 'user-123')
 * ```
 *
 * @module infrastructure/liveview
 */

import type { LiveViewBridge } from '../../application/interfaces/liveview-bridge.interface'

/**
 * LiveView Push Adapter
 *
 * Provides type-safe helper methods for pushing events to Phoenix LiveView server.
 * Validates payloads and delegates to LiveViewBridge.
 *
 * SOLID Principles:
 * - Single Responsibility: Only provides type-safe push helpers
 * - Open/Closed: Extensible by adding new push methods
 * - Liskov Substitution: Can be used anywhere push operations are needed
 * - Interface Segregation: Depends only on LiveViewBridge.pushEvent method
 * - Dependency Inversion: Depends on LiveViewBridge interface, not concrete implementation
 */
export class LiveViewPushAdapter {
  private readonly bridge: LiveViewBridge

  /**
   * Creates a new LiveViewPushAdapter
   *
   * @param bridge - The LiveViewBridge instance to use for pushing events
   *
   * @example
   * ```typescript
   * const bridge = new LiveViewEventBridge(this)
   * const adapter = new LiveViewPushAdapter(bridge)
   * ```
   */
  constructor(bridge: LiveViewBridge) {
    this.bridge = bridge
  }

  /**
   * Push a Yjs document update to the server
   *
   * @param update - Base64-encoded Yjs update data
   * @param completeState - Base64-encoded complete document state
   * @param userId - ID of the user making the update
   * @param markdown - Markdown representation of the document
   * @returns Promise that resolves when event is sent
   * @throws Error if any required parameter is empty
   */
  async pushYjsUpdate(
    update: string,
    completeState: string,
    userId: string,
    markdown: string
  ): Promise<void> {
    if (!update) {
      throw new Error('Update cannot be empty')
    }
    if (!completeState) {
      throw new Error('Complete state cannot be empty')
    }
    if (!userId) {
      throw new Error('User ID cannot be empty')
    }

    await this.bridge.pushEvent('yjs_update', {
      update,
      complete_state: completeState,
      user_id: userId,
      markdown
    })
  }

  /**
   * Push an awareness update to the server
   *
   * @param update - Base64-encoded awareness update data
   * @param userId - ID of the user whose awareness is updating
   * @returns Promise that resolves when event is sent
   * @throws Error if any required parameter is empty
   */
  async pushAwarenessUpdate(update: string, userId: string): Promise<void> {
    if (!update) {
      throw new Error('Update cannot be empty')
    }
    if (!userId) {
      throw new Error('User ID cannot be empty')
    }

    await this.bridge.pushEvent('awareness_update', {
      update,
      user_id: userId
    })
  }

  /**
   * Push an agent query to the server
   *
   * @param queryId - Unique identifier for this query
   * @param mention - The @mention that triggered the query
   * @param query - The query text
   * @returns Promise that resolves when event is sent
   * @throws Error if any required parameter is empty
   */
  async pushAgentQuery(
    queryId: string,
    mention: string,
    query: string
  ): Promise<void> {
    if (!queryId) {
      throw new Error('Query ID cannot be empty')
    }
    if (!mention) {
      throw new Error('Mention cannot be empty')
    }
    if (!query) {
      throw new Error('Query cannot be empty')
    }

    await this.bridge.pushEvent('agent_query', {
      query_id: queryId,
      mention,
      query
    })
  }

  /**
   * Push a chat message to the server
   *
   * @param message - The chat message text
   * @param userId - ID of the user sending the message
   * @returns Promise that resolves when event is sent
   * @throws Error if any required parameter is empty
   */
  async pushChatMessage(message: string, userId: string): Promise<void> {
    if (!message) {
      throw new Error('Message cannot be empty')
    }
    if (!userId) {
      throw new Error('User ID cannot be empty')
    }

    await this.bridge.pushEvent('chat_message', {
      message,
      user_id: userId
    })
  }
}
