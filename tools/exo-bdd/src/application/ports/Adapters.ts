import type { HttpPort } from './HttpPort.ts'
import type { BrowserPort } from './BrowserPort.ts'
import type { CliPort } from './CliPort.ts'
import type { GraphPort } from './GraphPort.ts'
import type { SecurityPort } from './SecurityPort.ts'

export interface Adapters {
  http?: HttpPort
  browser?: BrowserPort
  cli?: CliPort
  graph?: GraphPort
  security?: SecurityPort
  dispose(): Promise<void>
}
