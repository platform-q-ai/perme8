/**
 * SessionLogHook - Presentation Layer
 *
 * Auto-scrolls the session event log container as new events arrive.
 * Uses MutationObserver to detect new child elements added by LiveView.
 * Respects user scroll position -- only auto-scrolls if user is at the bottom.
 *
 * NO business logic - only DOM manipulation for scroll management.
 *
 * @module presentation/hooks
 */

import { ViewHook } from 'phoenix_live_view'

/**
 * Phoenix hook for session event log auto-scrolling
 *
 * Attaches to the session log container element and manages:
 * - Auto-scroll to bottom when new child elements are added by LiveView
 * - Respects user scroll position (won't auto-scroll if user scrolled up)
 *
 * @example
 * ```heex
 * <div
 *   id="session-log"
 *   phx-hook="SessionLog"
 *   class="h-64 overflow-y-auto"
 * >
 * </div>
 * ```
 */
export class SessionLogHook extends ViewHook {
  private isAtBottom: boolean = true
  private handleScroll?: () => void
  private observer?: MutationObserver

  /**
   * Phoenix hook lifecycle: mounted
   * Sets up scroll tracking and mutation observer for auto-scrolling
   */
  mounted(): void {
    this.isAtBottom = true

    this.handleScroll = () => {
      const { scrollTop, scrollHeight, clientHeight } = this.el
      this.isAtBottom = scrollHeight - scrollTop - clientHeight < 50
    }
    this.el.addEventListener('scroll', this.handleScroll)

    // Observe child additions to auto-scroll
    this.observer = new MutationObserver(() => {
      if (this.isAtBottom) {
        this.el.scrollTop = this.el.scrollHeight
      }
    })

    this.observer.observe(this.el, { childList: true, subtree: true })
  }

  /**
   * Phoenix hook lifecycle: updated
   * Re-check scroll position after LiveView update
   */
  updated(): void {
    if (this.isAtBottom) {
      this.el.scrollTop = this.el.scrollHeight
    }
  }

  /**
   * Phoenix hook lifecycle: destroyed
   * Cleanup scroll event listener and mutation observer
   */
  destroyed(): void {
    if (this.handleScroll) {
      this.el.removeEventListener('scroll', this.handleScroll)
    }
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}
