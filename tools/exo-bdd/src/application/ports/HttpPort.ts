import type { HttpResponse } from '../../domain/entities/index.ts'
import type { HttpAdapterConfig } from '../config/ConfigSchema.ts'

export interface HttpPort {
  // Configuration
  readonly config: HttpAdapterConfig

  // Request building (chainable, reset after each request)
  setHeader(name: string, value: string): this
  setHeaders(headers: Record<string, string>): this
  setQueryParam(name: string, value: string): this
  setQueryParams(params: Record<string, string>): this
  setBearerToken(token: string): this
  setBasicAuth(username: string, password: string): this

  // HTTP methods
  get(path: string): Promise<void>
  post(path: string, body?: unknown): Promise<void>
  put(path: string, body?: unknown): Promise<void>
  patch(path: string, body?: unknown): Promise<void>
  delete(path: string): Promise<void>
  request(method: string, path: string, body?: unknown): Promise<void>

  // Response accessors (from last request)
  readonly response: HttpResponse
  readonly status: number
  readonly statusText: string
  readonly headers: Record<string, string>
  readonly body: unknown
  readonly text: string
  readonly responseTime: number

  // Utilities
  getBodyPath(jsonPath: string): unknown

  // Lifecycle
  dispose(): Promise<void>
}
