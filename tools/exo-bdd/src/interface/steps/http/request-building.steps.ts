import { Given } from '@cucumber/cucumber'
import { TestWorld } from '../../world/index.ts'

/** Context required by request-building step handlers. */
export interface RequestBuildingContext {
  http: { setHeader(name: string, value: string): unknown; setQueryParam(name: string, value: string): unknown; setBearerToken(token: string): unknown; setBasicAuth(user: string, pass: string): unknown }
  interpolate(text: string): string
}

export function setHeader(ctx: RequestBuildingContext, name: string, value: string) {
  ctx.http.setHeader(name, ctx.interpolate(value))
}

export function setHeaders(ctx: RequestBuildingContext, headers: Record<string, string>) {
  for (const [name, value] of Object.entries(headers)) {
    ctx.http.setHeader(name, ctx.interpolate(value))
  }
}

export function setBearerToken(ctx: RequestBuildingContext, token: string) {
  ctx.http.setBearerToken(ctx.interpolate(token))
}

export function setBasicAuth(ctx: RequestBuildingContext, username: string, password: string) {
  ctx.http.setBasicAuth(ctx.interpolate(username), ctx.interpolate(password))
}

export function setQueryParam(ctx: RequestBuildingContext, name: string, value: string) {
  ctx.http.setQueryParam(name, ctx.interpolate(value))
}

export function setQueryParams(ctx: RequestBuildingContext, params: Record<string, string>) {
  for (const [name, value] of Object.entries(params)) {
    ctx.http.setQueryParam(name, ctx.interpolate(value))
  }
}

// ── Cucumber registrations (delegate to exported handlers) ────────────────

Given<TestWorld>(
  'I set header {string} to {string}',
  function (name: string, value: string) {
    setHeader(this, name, value)
  },
)

Given<TestWorld>(
  'I set the following headers:',
  function (dataTable) {
    setHeaders(this, dataTable.rowsHash() as Record<string, string>)
  },
)

Given<TestWorld>(
  'I set bearer token to {string}',
  function (token: string) {
    setBearerToken(this, token)
  },
)

Given<TestWorld>(
  'I set basic auth with username {string} and password {string}',
  function (username: string, password: string) {
    setBasicAuth(this, username, password)
  },
)

Given<TestWorld>(
  'I set query param {string} to {string}',
  function (name: string, value: string) {
    setQueryParam(this, name, value)
  },
)

Given<TestWorld>(
  'I set the following query params:',
  function (dataTable) {
    setQueryParams(this, dataTable.rowsHash() as Record<string, string>)
  },
)
