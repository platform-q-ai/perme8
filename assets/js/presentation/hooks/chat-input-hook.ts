/**
 * ChatInputHook - Phoenix Hook for Chat Input Textarea
 *
 * Thin Phoenix hook that handles chat input keyboard events and form submission.
 * NO business logic - only DOM event handling.
 *
 * Responsibilities:
 * - Handle Enter key to submit form (without Shift)
 * - Handle Shift+Enter for new lines (default behavior)
 * - Keep focus on input after form submission
 *
 * This hook is THIN - it only handles DOM events. The actual message sending
 * is handled by LiveView form submission.
 *
 * @module presentation/hooks
 */

import { ViewHook } from 'phoenix_live_view'

/**
 * Phoenix hook for chat input textarea
 *
 * Attaches to the chat input element and handles:
 * - Enter key submission (without Shift)
 * - Shift+Enter for new lines
 * - Auto-focus after form submission
 * - Message validation before submission
 *
 * @example
 * ```heex
 * <textarea
 *   id="chat-input"
 *   phx-hook="ChatInput"
 *   placeholder="Type a message..."
 * />
 * ```
 */
export class ChatInputHook extends ViewHook<HTMLTextAreaElement> {
  updated = (): void => {
    // Optional lifecycle hook - called when element attributes change
  }

  private handleKeydown?: (e: KeyboardEvent) => void

  /**
   * Phoenix hook lifecycle: mounted
   * Called when the element is added to the DOM
   */
  mounted(): void {
    // Handle Enter key submission
    this.handleKeydown = (e: KeyboardEvent) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault()

        const form = this.el.closest('form')
        if (form && this.el.value.trim() !== '') {
          // Trigger LiveView form submission by dispatching a submit event
          // DO NOT use form.submit() as it bypasses LiveView and causes page reload
          form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }))
        }
      }
      // Shift+Enter creates new line (default textarea behavior)
    }

    this.el.addEventListener('keydown', this.handleKeydown)

    // Set updated lifecycle method
    this.updated = () => {
      // Keep focus on input after form submission and LiveView updates
      // Only refocus if drawer is still open
      const drawer = this.el.closest('.drawer')
      if (drawer) {
        const checkbox = drawer.querySelector('input[type="checkbox"]') as HTMLInputElement
        if (checkbox && checkbox.checked && document.activeElement !== this.el) {
          this.el.focus()
        }
      }
    }
  }

  /**
   * Phoenix hook lifecycle: destroyed
   * Called when the element is removed from the DOM
   */
  destroyed(): void {
    if (this.handleKeydown) {
      this.el.removeEventListener('keydown', this.handleKeydown)
    }
  }
}
