/**
 * ChatMessagesHook - Phoenix Hook for Chat Messages Auto-Scroll
 *
 * Extremely simple Phoenix hook that auto-scrolls the messages container
 * to the bottom when messages are added.
 *
 * Responsibilities:
 * - Scroll to bottom on mount (initial load)
 * - Scroll to bottom on update (new messages)
 *
 * This hook is pure UI behavior - no business logic, no use cases.
 *
 * @module presentation/hooks
 */

import { ViewHook } from 'phoenix_live_view'

/**
 * Phoenix hook for chat messages auto-scroll behavior
 *
 * Attaches to the chat messages container element and automatically
 * scrolls to the bottom whenever messages are added.
 *
 * @example
 * ```heex
 * <div
 *   id="chat-messages"
 *   phx-hook="ChatMessages"
 *   class="overflow-y-auto"
 * >
 *   <!-- Messages rendered here -->
 * </div>
 * ```
 */
export class ChatMessagesHook extends ViewHook {

  /**
   * Phoenix hook lifecycle: mounted
   * Called when the element is added to the DOM
   */
  mounted(): void {
    this.scrollToBottom()
  }

  /**
   * Phoenix hook lifecycle: updated
   * Called when LiveView updates the element content
   */
  updated(): void {
    this.scrollToBottom()
  }

  /**
   * Scrolls the container to the bottom
   */
  private scrollToBottom(): void {
    this.el.scrollTop = this.el.scrollHeight
  }
}
