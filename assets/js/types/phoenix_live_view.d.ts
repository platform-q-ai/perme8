/**
 * Type declarations for Phoenix LiveView JavaScript client
 *
 * This provides minimal type safety for the LiveView Socket and Hooks APIs.
 * These types are based on Phoenix LiveView 1.0+ API.
 */

declare module "phoenix_live_view" {
  import { Socket as PhoenixSocket } from "phoenix"

  export class LiveSocket {
    constructor(url: string, socketConstructor: typeof PhoenixSocket, opts?: LiveSocketOptions)

    connect(): void
    disconnect(callback?: () => void): void
    enableDebug(): void
    enableLatencySim(upperBoundMs: number): void
    disableDebug(): void
    disableLatencySim(): void
    getLatencySim(): number | null
    getSocket(): PhoenixSocket
    isConnected(): boolean
    isLoading(): boolean
  }

  export interface LiveSocketOptions {
    params?: { [key: string]: any } | (() => { [key: string]: any })
    hooks?: { [key: string]: ViewHook }
    dom?: DOMOptions
    uploaders?: { [key: string]: Uploader }
    longPollFallbackMs?: number
    metadata?: Metadata
  }

  export interface DOMOptions {
    onBeforeElUpdated?: (from: HTMLElement, to: HTMLElement) => boolean
  }

  export interface Metadata {
    click?: (event: Event, element: HTMLElement) => any
    keydown?: (event: KeyboardEvent, element: HTMLElement) => any
  }

  export interface Uploader {
    (entries: FileEntry[], onViewError: () => void): void
  }

  export interface FileEntry {
    file: File
    ref: string
    uuid: string
    progress: number
    preflighted: boolean
    cancelled: boolean
    done: boolean
  }

  export type CallbackRef = number | string

  export type OnReply = (reply: any, ref: CallbackRef) => void

  /**
   * ViewHook base class for Phoenix LiveView hooks
   *
   * Hooks are classes that provide lifecycle callbacks for LiveView DOM elements.
   * Extend this class and implement the lifecycle methods you need.
   *
   * In tests, pass null for view and provide a mock element with phxPrivate property:
   * @example
   * const element = document.createElement('div')
   * ;(element as any).phxPrivate = {}
   * const hook = new MyHook(null as any, element)
   */
  export abstract class ViewHook<T extends HTMLElement = HTMLElement> {
    el!: T
    viewName?: string
    liveSocket?: LiveSocket
    pushEvent!: (event: string, payload?: any, onReply?: OnReply) => Promise<any>
    pushEventTo!: (selector: string, event: string, payload?: any, onReply?: OnReply) => void
    handleEvent!: (event: string, callback: (payload: any) => any) => CallbackRef
    removeHandleEvent!: (callbackRef: CallbackRef) => void
    upload?: (name: string, files: FileList | File[]) => void
    uploadTo?: (selector: string, name: string, files: FileList | File[]) => void

    constructor(view: any, el: T, callbacks?: any)

    mounted?(): void
    updated?(): void
    beforeUpdate?(): void
    destroyed?(): void
    disconnected?(): void
    reconnected?(): void
  }
}
