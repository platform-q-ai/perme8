/**
 * BeaconSender
 *
 * Wraps navigator.sendBeacon API for reliable data sending during page unload.
 * sendBeacon queues data to be sent asynchronously even if page is closing.
 */
export class BeaconSender {
  /**
   * Checks if sendBeacon is supported by the browser
   * @returns True if sendBeacon is available, false otherwise
   */
  isBeaconSupported(): boolean {
    return typeof navigator !== 'undefined' && typeof navigator.sendBeacon === 'function'
  }

  /**
   * Sends data using sendBeacon API
   * @param url - Target URL
   * @param data - Data to send (will be JSON serialized)
   * @returns True if beacon was queued successfully, false otherwise
   */
  send(url: string, data: Record<string, any>): boolean {
    if (!this.isBeaconSupported()) {
      return false
    }

    try {
      // Create JSON blob with correct content type
      const blob = new Blob([JSON.stringify(data)], { type: 'application/json' })

      // sendBeacon returns true if data was queued, false otherwise
      return navigator.sendBeacon(url, blob)
    } catch (error) {
      console.error('BeaconSender error:', error)
      return false
    }
  }
}
