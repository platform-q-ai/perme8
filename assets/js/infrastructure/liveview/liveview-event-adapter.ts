/**
 * LiveViewEventAdapter
 *
 * Simple adapter for Phoenix LiveView event communication.
 * Implements ILiveViewEventAdapter interface.
 */

import { ILiveViewEventAdapter } from '../../application/interfaces/liveview-event-adapter'

export class LiveViewEventAdapter implements ILiveViewEventAdapter {
  constructor(
    private pushEventFn: (event: string, payload: any) => void,
    private handleEventFn: (event: string, callback: (payload: any) => void) => void
  ) {}

  pushEvent(event: string, payload: any): void {
    this.pushEventFn(event, payload)
  }

  handleEvent(event: string, callback: (payload: any) => void): void {
    this.handleEventFn(event, callback)
  }
}
