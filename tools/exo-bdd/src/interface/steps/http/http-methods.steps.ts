import { When } from '@cucumber/cucumber'
import { TestWorld } from '../../world/index.ts'

/** Context required by HTTP method step handlers. */
export interface HttpMethodsContext {
  http: { get(path: string): Promise<void>; post(path: string, body?: unknown): Promise<void>; put(path: string, body?: unknown): Promise<void>; patch(path: string, body?: unknown): Promise<void>; delete(path: string): Promise<void>; request(method: string, path: string, body?: unknown): Promise<void> }
  interpolate(text: string): string
}

export async function httpGet(ctx: HttpMethodsContext, path: string) {
  await ctx.http.get(ctx.interpolate(path))
}

export async function httpPost(ctx: HttpMethodsContext, path: string) {
  await ctx.http.post(ctx.interpolate(path))
}

export async function httpPostWithBody(ctx: HttpMethodsContext, path: string, docString: string) {
  const body = JSON.parse(ctx.interpolate(docString))
  await ctx.http.post(ctx.interpolate(path), body)
}

export async function httpPostWithRawBody(ctx: HttpMethodsContext, path: string, docString: string) {
  await ctx.http.post(ctx.interpolate(path), ctx.interpolate(docString))
}

export async function httpPutWithBody(ctx: HttpMethodsContext, path: string, docString: string) {
  const body = JSON.parse(ctx.interpolate(docString))
  await ctx.http.put(ctx.interpolate(path), body)
}

export async function httpPatchWithBody(ctx: HttpMethodsContext, path: string, docString: string) {
  const body = JSON.parse(ctx.interpolate(docString))
  await ctx.http.patch(ctx.interpolate(path), body)
}

export async function httpDelete(ctx: HttpMethodsContext, path: string) {
  await ctx.http.delete(ctx.interpolate(path))
}

export async function httpRequest(ctx: HttpMethodsContext, method: string, path: string) {
  await ctx.http.request(method.toUpperCase(), ctx.interpolate(path))
}

export async function httpRequestWithBody(ctx: HttpMethodsContext, method: string, path: string, docString: string) {
  const body = JSON.parse(ctx.interpolate(docString))
  await ctx.http.request(method.toUpperCase(), ctx.interpolate(path), body)
}

// ── Cucumber registrations (delegate to exported handlers) ────────────────

When<TestWorld>('I GET {string}', async function (path: string) {
  await httpGet(this, path)
})

When<TestWorld>('I POST to {string}', async function (path: string) {
  await httpPost(this, path)
})

When<TestWorld>('I POST to {string} with body:', async function (path: string, docString: string) {
  await httpPostWithBody(this, path, docString)
})

When<TestWorld>('I POST raw to {string} with body:', async function (path: string, docString: string) {
  await httpPostWithRawBody(this, path, docString)
})

When<TestWorld>('I PUT to {string} with body:', async function (path: string, docString: string) {
  await httpPutWithBody(this, path, docString)
})

When<TestWorld>('I PATCH to {string} with body:', async function (path: string, docString: string) {
  await httpPatchWithBody(this, path, docString)
})

When<TestWorld>('I DELETE {string}', async function (path: string) {
  await httpDelete(this, path)
})

When<TestWorld>('I send a {word} request to {string}', async function (method: string, path: string) {
  await httpRequest(this, method, path)
})

When<TestWorld>('I send a {word} request to {string} with body:', async function (method: string, path: string, docString: string) {
  await httpRequestWithBody(this, method, path, docString)
})
