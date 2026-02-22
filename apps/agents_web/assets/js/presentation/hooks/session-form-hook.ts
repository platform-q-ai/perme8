/**
 * SessionFormHook - Presentation Layer
 *
 * Handles keyboard submit behavior for the session instruction textarea.
 * Enter submits the form, Shift+Enter inserts a newline.
 *
 * NO business logic - only DOM event interception for keyboard shortcuts.
 *
 * @module presentation/hooks
 */

import { ViewHook } from 'phoenix_live_view'

/**
 * Phoenix hook for session form keyboard submit
 *
 * Attaches to the textarea element and intercepts keydown events:
 * - Enter (without Shift): prevents default newline, submits the parent form
 * - Shift+Enter: allows default behavior (inserts newline)
 *
 * @example
 * ```heex
 * <textarea
 *   id="session-instruction"
 *   phx-hook="SessionForm"
 * />
 * ```
 */
export class SessionFormHook extends ViewHook<HTMLTextAreaElement> {
  private handleKeydown?: (e: KeyboardEvent) => void

  /**
   * Phoenix hook lifecycle: mounted
   * Sets up keydown listener for Enter-to-submit behavior
   */
  mounted(): void {
    this.handleKeydown = (e: KeyboardEvent) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault()
        const form = this.el.closest('form')
        if (form) {
          form.dispatchEvent(
            new Event('submit', { bubbles: true, cancelable: true })
          )
        }
      }
    }
    this.el.addEventListener('keydown', this.handleKeydown)
  }

  /**
   * Phoenix hook lifecycle: destroyed
   * Cleanup keydown event listener
   */
  destroyed(): void {
    if (this.handleKeydown) {
      this.el.removeEventListener('keydown', this.handleKeydown)
    }
  }
}
