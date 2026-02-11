export interface HttpResponse {
  readonly status: number
  readonly statusText: string
  readonly headers: Readonly<Record<string, string>>
  readonly body: unknown
  readonly text: string
  readonly responseTime: number
}
