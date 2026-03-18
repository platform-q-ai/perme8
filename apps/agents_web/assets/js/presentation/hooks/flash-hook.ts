/**
 * FlashHook - Presentation Layer
 *
 * Thin Phoenix hook for flash message auto-hide behavior.
 *
 * Responsibilities:
 * - Auto-hide flash message after timeout (default 5 seconds)
 * - Fade out animation using CSS classes
 * - Remove element from DOM after fade completes
 * - Configurable timeout via data attribute
 * - Handle manual close button clicks
 *
 * NO business logic - only DOM manipulation and timing.
 */

import { ViewHook } from "phoenix_live_view";

// Constants for timing and CSS classes
const DEFAULT_AUTO_HIDE_TIMEOUT = 5000; // 5 seconds
const FADE_ANIMATION_DURATION = 300; // 300ms to match CSS animation
const FADE_OUT_CLASS = "fade-out";
const CLOSE_BUTTON_SELECTOR = ".flash-close";

/**
 * Phoenix hook for FlashHook - extends ViewHook base class
 */
export class FlashHook extends ViewHook {
  private autoHideTimer?: ReturnType<typeof setTimeout>;
  private removeTimer?: ReturnType<typeof setTimeout>;
  private closeButton?: HTMLButtonElement | null;
  private handleCloseClick?: () => void;

  /**
   * Phoenix hook lifecycle - mounted
   * Sets up auto-hide timer and close button handler
   */
  mounted(): void {
    const timeoutMs = this.getTimeout();

    this.setupCloseButton();
    this.setupAutoHideTimer(timeoutMs);
  }

  /**
   * Phoenix hook lifecycle - destroyed
   * Cleanup timers and event listeners
   */
  destroyed(): void {
    // Clear auto-hide timer
    if (this.autoHideTimer) {
      clearTimeout(this.autoHideTimer);
      this.autoHideTimer = undefined;
    }

    // Clear remove timer
    if (this.removeTimer) {
      clearTimeout(this.removeTimer);
      this.removeTimer = undefined;
    }

    // Remove close button listener
    if (this.closeButton && this.handleCloseClick) {
      this.closeButton.removeEventListener("click", this.handleCloseClick);
    }
  }

  /**
   * Get timeout from data attribute or use default
   * @returns Timeout in milliseconds
   */
  private getTimeout(): number {
    const timeout = parseInt(this.el.dataset.timeout || "", 10);

    // Validate timeout (must be positive number)
    if (isNaN(timeout) || timeout <= 0) {
      return DEFAULT_AUTO_HIDE_TIMEOUT;
    }

    return timeout;
  }

  /**
   * Setup close button event listener
   */
  private setupCloseButton(): void {
    this.closeButton = this.el.querySelector(CLOSE_BUTTON_SELECTOR);

    if (this.closeButton) {
      this.handleCloseClick = () => this.startFadeOut();
      this.closeButton.addEventListener("click", this.handleCloseClick);
    }
  }

  /**
   * Setup auto-hide timer
   * @param timeoutMs - Timeout in milliseconds
   */
  private setupAutoHideTimer(timeoutMs: number): void {
    this.autoHideTimer = setTimeout(() => {
      this.startFadeOut();
    }, timeoutMs);
  }

  /**
   * Start fade out animation and schedule element removal
   */
  private startFadeOut(): void {
    // Cancel auto-hide timer if still pending
    if (this.autoHideTimer) {
      clearTimeout(this.autoHideTimer);
      this.autoHideTimer = undefined;
    }

    // Add fade-out CSS class
    this.el.classList.add(FADE_OUT_CLASS);

    // Schedule element removal after animation completes
    this.removeTimer = setTimeout(() => {
      this.el.remove();
    }, FADE_ANIMATION_DURATION);
  }
}
