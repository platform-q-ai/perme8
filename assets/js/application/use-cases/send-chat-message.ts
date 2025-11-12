/**
 * SendChatMessage Use Case
 *
 * Orchestrates sending a chat message to the LiveView server.
 *
 * @module application/use-cases
 */

import type { LiveViewBridge } from '../interfaces/liveview-bridge.interface'

/**
 * Use case for sending chat messages to the LiveView server
 *
 * Responsibilities:
 * - Validates message is not empty
 * - Trims whitespace from message
 * - Pushes chat message event to LiveView server
 *
 * Dependencies (injected):
 * - LiveViewBridge: For pushing events to Phoenix LiveView
 *
 * @example
 * ```typescript
 * const bridge = new PhoenixLiveViewBridge(hook)
 * const sendMessage = new SendChatMessage(bridge)
 *
 * await sendMessage.execute('Hello, world!', 'user-123')
 * // Sends chat message to server
 * ```
 */
export class SendChatMessage {
  /**
   * Creates a new SendChatMessage use case
   *
   * @param bridge - LiveView bridge for server communication
   */
  constructor(private readonly bridge: LiveViewBridge) {}

  /**
   * Sends a chat message to the LiveView server
   *
   * @param message - The message text to send
   * @param userId - ID of the user sending the message
   * @throws {Error} If message is empty after trimming
   * @throws {Error} If user ID is empty
   *
   * @example
   * ```typescript
   * await sendMessage.execute('Hello!', 'user-123')
   * ```
   */
  async execute(message: string, userId: string): Promise<void> {
    // Validate user ID
    if (!userId || userId.trim().length === 0) {
      throw new Error('User ID cannot be empty')
    }

    // Trim whitespace from message
    const trimmedMessage = message.trim()

    // Validate message is not empty
    if (trimmedMessage.length === 0) {
      throw new Error('Message cannot be empty')
    }

    // Push chat message event to server
    await this.bridge.pushEvent('chat_message', {
      message: trimmedMessage,
      user_id: userId
    })
  }
}
