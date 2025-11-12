/**
 * Type declarations for Phoenix JavaScript client
 *
 * This provides minimal type safety for the Phoenix Socket and Channel APIs.
 * For full type definitions, consider using @types/phoenix if available.
 */

declare module "phoenix" {
  export class Socket {
    constructor(endPoint: string, opts?: SocketOptions)

    connect(): void
    disconnect(callback?: () => void, code?: number, reason?: string): void
    channel(topic: string, chanParams?: object): Channel
    onOpen(callback: () => void): void
    onClose(callback: (event: any) => void): void
    onError(callback: (error: any) => void): void
    onMessage(callback: (message: any) => any): void
    connectionState(): string
    isConnected(): boolean
  }

  export interface SocketOptions {
    timeout?: number
    transport?: any
    encode?: (payload: any, callback: (encoded: any) => void) => void
    decode?: (payload: any, callback: (decoded: any) => void) => void
    heartbeatIntervalMs?: number
    reconnectAfterMs?: (tries: number) => number
    rejoinAfterMs?: (tries: number) => number
    logger?: (kind: string, msg: string, data: any) => void
    longpollerTimeout?: number
    params?: any
    vsn?: string
  }

  export class Channel {
    constructor(topic: string, params: any, socket: Socket)

    join(timeout?: number): Push
    leave(timeout?: number): Push
    on(event: string, callback: (payload: any) => void): number
    off(event: string, ref?: number): void
    push(event: string, payload: any, timeout?: number): Push
    onError(callback: (reason?: any) => void): void
    onClose(callback: (reason?: any) => void): void
  }

  export class Push {
    receive(status: string, callback: (response: any) => void): Push
  }

  export class Presence {
    static syncState(currentState: any, newState: any, onJoin?: Function, onLeave?: Function): any
    static syncDiff(currentState: any, diff: any, onJoin?: Function, onLeave?: Function): any
    static list(presences: any, chooser?: Function): any[]
  }

  export class LongPoll {
    constructor(endPoint: string)
  }
}
