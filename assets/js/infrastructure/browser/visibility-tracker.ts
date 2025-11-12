/**
 * VisibilityTracker
 *
 * Wraps browser visibility API (document.hidden, visibilitychange event)
 * for tracking when page becomes visible/hidden (tab switching, minimizing)
 */
export class VisibilityTracker {
  private listener: (() => void) | null = null

  /**
   * Creates a visibility tracker
   * @param callback - Called when visibility changes with new visible state (true = visible, false = hidden)
   */
  constructor(private callback: (isVisible: boolean) => void) {}

  /**
   * Starts tracking visibility changes
   */
  start(): void {
    // Create listener that converts document.hidden to isVisible
    this.listener = () => {
      const isVisible = !document.hidden
      this.callback(isVisible)
    }

    document.addEventListener('visibilitychange', this.listener)
  }

  /**
   * Stops tracking visibility changes
   */
  stop(): void {
    if (this.listener) {
      document.removeEventListener('visibilitychange', this.listener)
      this.listener = null
    }
  }

  /**
   * Gets current visibility state
   * @returns True if document is visible, false if hidden
   */
  isVisible(): boolean {
    return !document.hidden
  }
}
