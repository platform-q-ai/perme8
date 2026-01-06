/**
 * CopyToClipboardHook - Presentation Layer
 *
 * Thin Phoenix hook for copying text to clipboard.
 *
 * Responsibilities:
 * - Listen for phx:copy event
 * - Copy element's text content to clipboard
 * - Show visual feedback on success/failure
 *
 * NO business logic - only clipboard API and DOM manipulation.
 */

import { ViewHook } from "phoenix_live_view";

/**
 * Phoenix hook for CopyToClipboard - extends ViewHook base class
 */
export class CopyToClipboardHook extends ViewHook {
  /**
   * Phoenix hook lifecycle - mounted
   * Sets up event listener for copy events
   */
  mounted(): void {
    this.el.addEventListener("phx:copy", () => this.copyToClipboard());
  }

  /**
   * Copy element's text content to clipboard
   */
  private async copyToClipboard(): Promise<void> {
    const text = this.el.textContent?.trim() || "";

    if (!text) {
      console.warn("[CopyToClipboard] No text content to copy");
      return;
    }

    try {
      await navigator.clipboard.writeText(text);
      this.showFeedback(true);
    } catch (error) {
      console.error("[CopyToClipboard] Failed to copy:", error);
      this.showFeedback(false);
    }
  }

  /**
   * Show visual feedback after copy attempt
   * @param success - Whether the copy was successful
   */
  private showFeedback(success: boolean): void {
    const originalClass = this.el.className;

    if (success) {
      // Brief green highlight for success
      this.el.classList.add("bg-success/20");
      setTimeout(() => {
        this.el.className = originalClass;
      }, 500);
    } else {
      // Brief red highlight for failure
      this.el.classList.add("bg-error/20");
      setTimeout(() => {
        this.el.className = originalClass;
      }, 500);
    }
  }
}
