export interface HttpRequest {
  readonly method: string
  readonly url: string
  readonly headers: Readonly<Record<string, string>>
  readonly body?: unknown
  readonly queryParams?: Readonly<Record<string, string>>
}
