import { request, type APIRequestContext, type APIResponse } from '@playwright/test'
import type { HttpPort } from '../../../application/ports/index.ts'
import type { HttpAdapterConfig } from '../../../application/config/index.ts'
import type { HttpResponse } from '../../../domain/entities/index.ts'
import JSONPath from 'jsonpath'

export class PlaywrightHttpAdapter implements HttpPort {
  private context!: APIRequestContext
  private pendingHeaders: Record<string, string> = {}
  private pendingQueryParams: Record<string, string> = {}
  private _response?: HttpResponse
  private rawResponse?: APIResponse

  constructor(readonly config: HttpAdapterConfig) {}

  async initialize(): Promise<void> {
    this.context = await request.newContext({
      baseURL: this.config.baseURL,
      timeout: this.config.timeout ?? 30000,
      extraHTTPHeaders: this.config.headers,
    })
  }

  setHeader(name: string, value: string): this {
    this.pendingHeaders[name] = value
    return this
  }

  setHeaders(headers: Record<string, string>): this {
    Object.assign(this.pendingHeaders, headers)
    return this
  }

  setQueryParam(name: string, value: string): this {
    this.pendingQueryParams[name] = value
    return this
  }

  setQueryParams(params: Record<string, string>): this {
    Object.assign(this.pendingQueryParams, params)
    return this
  }

  setBearerToken(token: string): this {
    return this.setHeader('Authorization', `Bearer ${token}`)
  }

  setBasicAuth(username: string, password: string): this {
    const encoded = btoa(`${username}:${password}`)
    return this.setHeader('Authorization', `Basic ${encoded}`)
  }

  async get(path: string): Promise<void> {
    await this.request('GET', path)
  }

  async post(path: string, body?: unknown): Promise<void> {
    await this.request('POST', path, body)
  }

  async put(path: string, body?: unknown): Promise<void> {
    await this.request('PUT', path, body)
  }

  async patch(path: string, body?: unknown): Promise<void> {
    await this.request('PATCH', path, body)
  }

  async delete(path: string): Promise<void> {
    await this.request('DELETE', path)
  }

  async request(method: string, path: string, body?: unknown): Promise<void> {
    const startTime = Date.now()

    const url = this.buildUrl(path)
    this.rawResponse = await this.context.fetch(url, {
      method,
      headers: this.pendingHeaders,
      data: body,
    })

    const responseBody = await this.rawResponse.text()

    this._response = {
      status: this.rawResponse.status(),
      statusText: this.rawResponse.statusText(),
      headers: Object.fromEntries(
        this.rawResponse.headersArray().map((h) => [h.name, h.value]),
      ),
      body: this.parseBody(responseBody),
      text: responseBody,
      responseTime: Date.now() - startTime,
    }

    this.resetPending()
  }

  private guardResponse(): HttpResponse {
    if (!this._response) {
      throw new Error('No HTTP request has been made yet. Call a request method (get, post, etc.) before accessing the response.')
    }
    return this._response
  }

  get response(): HttpResponse {
    return this.guardResponse()
  }

  get status(): number {
    return this.guardResponse().status
  }

  get statusText(): string {
    return this.guardResponse().statusText
  }

  get headers(): Record<string, string> {
    return this.guardResponse().headers
  }

  get body(): unknown {
    return this.guardResponse().body
  }

  get text(): string {
    return this.guardResponse().text
  }

  get responseTime(): number {
    return this.guardResponse().responseTime
  }

  getBodyPath(jsonPath: string): unknown {
    return JSONPath.query(this.guardResponse().body, jsonPath)[0]
  }

  async dispose(): Promise<void> {
    await this.context.dispose()
  }

  private buildUrl(path: string): string {
    const url = new URL(path, this.config.baseURL)
    Object.entries(this.pendingQueryParams).forEach(([k, v]) => url.searchParams.set(k, v))
    return url.toString()
  }

  private parseBody(text: string): unknown {
    try {
      return JSON.parse(text)
    } catch {
      return text
    }
  }

  private resetPending(): void {
    this.pendingHeaders = {}
    this.pendingQueryParams = {}
  }
}
