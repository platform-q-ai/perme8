/**
 * ILiveViewEventAdapter
 *
 * Interface for communicating with Phoenix LiveView.
 * Abstracts Phoenix-specific details from the application layer.
 */

export interface ILiveViewEventAdapter {
  /**
   * Push an event to the LiveView server
   */
  pushEvent(event: string, payload: any): void

  /**
   * Handle an event from the LiveView server
   */
  handleEvent(event: string, callback: (payload: any) => void): void
}
