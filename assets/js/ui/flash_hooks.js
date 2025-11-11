/**
 * AutoHideFlash Hook
 *
 * Automatically hides flash messages after 1 second
 */
export const AutoHideFlash = {
  mounted() {
    // Auto-hide after 1 second (1000ms)
    this.timeout = setTimeout(() => {
      // Trigger the phx-click event to hide the flash
      this.el.click()
    }, 1000)
  },

  destroyed() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}
