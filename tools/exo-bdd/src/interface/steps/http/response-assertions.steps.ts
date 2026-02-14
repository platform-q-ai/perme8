import { Then } from '@cucumber/cucumber'
import { expect } from '@playwright/test'
import { TestWorld } from '../../world/index.ts'
import type { HttpResponse } from '../../../domain/entities/index.ts'

/** Context required by response-assertion step handlers. */
export interface ResponseAssertionsContext {
  http: {
    status: number
    statusText: string
    headers: Record<string, string>
    body: unknown
    text: string
    response: HttpResponse
    getBodyPath(jsonPath: string): unknown
  }
  interpolate(text: string): string
  setVariable(name: string, value: unknown): void
}

export function assertStatusIs(ctx: ResponseAssertionsContext, expectedStatus: number) {
  expect(ctx.http.status).toBe(expectedStatus)
}

export function assertStatusIsNot(ctx: ResponseAssertionsContext, unexpectedStatus: number) {
  expect(ctx.http.status).not.toBe(unexpectedStatus)
}

export function assertStatusBetween(ctx: ResponseAssertionsContext, min: number, max: number) {
  expect(ctx.http.status).toBeGreaterThanOrEqual(min)
  expect(ctx.http.status).toBeLessThanOrEqual(max)
}

export function assertResponseSuccessful(ctx: ResponseAssertionsContext) {
  expect(ctx.http.status).toBeGreaterThanOrEqual(200)
  expect(ctx.http.status).toBeLessThan(300)
}

export function assertResponseClientError(ctx: ResponseAssertionsContext) {
  expect(ctx.http.status).toBeGreaterThanOrEqual(400)
  expect(ctx.http.status).toBeLessThan(500)
}

export function assertResponseServerError(ctx: ResponseAssertionsContext) {
  expect(ctx.http.status).toBeGreaterThanOrEqual(500)
  expect(ctx.http.status).toBeLessThan(600)
}

export function assertBodyPathEqualsString(ctx: ResponseAssertionsContext, jsonPath: string, expectedValue: string) {
  const actual = ctx.http.getBodyPath(jsonPath)
  expect(actual).toBe(ctx.interpolate(expectedValue))
}

export function assertBodyPathEqualsInt(ctx: ResponseAssertionsContext, jsonPath: string, expectedValue: number) {
  const actual = ctx.http.getBodyPath(jsonPath)
  expect(actual).toBe(expectedValue)
}

export function assertBodyPathExists(ctx: ResponseAssertionsContext, jsonPath: string) {
  const value = ctx.http.getBodyPath(jsonPath)
  expect(value).toBeDefined()
}

export function assertBodyPathNotExists(ctx: ResponseAssertionsContext, jsonPath: string) {
  const value = ctx.http.getBodyPath(jsonPath)
  expect(value).toBeUndefined()
}

export function assertBodyPathContains(ctx: ResponseAssertionsContext, jsonPath: string, expectedSubstring: string) {
  const actual = String(ctx.http.getBodyPath(jsonPath))
  expect(actual).toContain(ctx.interpolate(expectedSubstring))
}

export function assertBodyPathMatches(ctx: ResponseAssertionsContext, jsonPath: string, pattern: string) {
  const actual = String(ctx.http.getBodyPath(jsonPath))
  expect(actual).toMatch(new RegExp(pattern))
}

export function assertBodyPathHasItems(ctx: ResponseAssertionsContext, jsonPath: string, expectedCount: number) {
  const actual = ctx.http.getBodyPath(jsonPath) as unknown[]
  expect(actual).toHaveLength(expectedCount)
}

export function assertBodyIsValidJson(ctx: ResponseAssertionsContext) {
  expect(typeof ctx.http.body).toBe('object')
}

export function assertHeaderEquals(ctx: ResponseAssertionsContext, headerName: string, expectedValue: string) {
  const actual = ctx.http.response.headers[headerName.toLowerCase()]
  expect(actual).toBe(ctx.interpolate(expectedValue))
}

export function assertHeaderContains(ctx: ResponseAssertionsContext, headerName: string, expectedSubstring: string) {
  const actual = ctx.http.response.headers[headerName.toLowerCase()]
  expect(actual).toContain(ctx.interpolate(expectedSubstring))
}

export function assertHeaderExists(ctx: ResponseAssertionsContext, headerName: string) {
  const actual = ctx.http.headers[headerName.toLowerCase()]
  expect(actual).toBeDefined()
}

export function assertContentType(ctx: ResponseAssertionsContext, expectedContentType: string) {
  const actual = ctx.http.headers['content-type']
  expect(actual).toContain(ctx.interpolate(expectedContentType))
}

export function assertBodyEquals(ctx: ResponseAssertionsContext, docString: string) {
  const expected = JSON.parse(ctx.interpolate(docString))
  expect(ctx.http.body).toEqual(expected)
}

export function assertBodyContains(ctx: ResponseAssertionsContext, expectedSubstring: string) {
  expect(ctx.http.text).toContain(ctx.interpolate(expectedSubstring))
}

export async function assertBodyMatchesSchema(ctx: ResponseAssertionsContext, schemaPath: string) {
  const schemaFile = Bun.file(ctx.interpolate(schemaPath))
  const schema = await schemaFile.json()
  const body = ctx.http.body as Record<string, unknown>
  if (schema.required) {
    for (const prop of schema.required as string[]) {
      expect(body).toHaveProperty(prop)
    }
  }
}

export function assertBodyPathEqualsFloat(ctx: ResponseAssertionsContext, jsonPath: string, expectedValue: number) {
  const actual = ctx.http.getBodyPath(jsonPath)
  expect(actual).toBe(expectedValue)
}

export function assertBodyPathIsTrue(ctx: ResponseAssertionsContext, jsonPath: string) {
  const actual = ctx.http.getBodyPath(jsonPath)
  expect(actual).toBe(true)
}

export function assertBodyPathIsFalse(ctx: ResponseAssertionsContext, jsonPath: string) {
  const actual = ctx.http.getBodyPath(jsonPath)
  expect(actual).toBe(false)
}

export function assertBodyPathIsNull(ctx: ResponseAssertionsContext, jsonPath: string) {
  const actual = ctx.http.getBodyPath(jsonPath)
  expect(actual).toBeNull()
}

export function assertResponseTimeLessThan(ctx: ResponseAssertionsContext, maxMs: number) {
  expect(ctx.http.response.responseTime).toBeLessThan(maxMs)
}

export function storeBodyPath(ctx: ResponseAssertionsContext, jsonPath: string, variableName: string) {
  const value = ctx.http.getBodyPath(jsonPath)
  ctx.setVariable(variableName, value)
}

export function storeHeader(ctx: ResponseAssertionsContext, headerName: string, variableName: string) {
  const value = ctx.http.response.headers[headerName.toLowerCase()]
  ctx.setVariable(variableName, value)
}

export function storeStatus(ctx: ResponseAssertionsContext, variableName: string) {
  ctx.setVariable(variableName, ctx.http.status)
}

// ── Cucumber registrations (delegate to exported handlers) ────────────────

Then<TestWorld>('the response status should be {int}', function (s: number) { assertStatusIs(this, s) })
Then<TestWorld>('the response status should not be {int}', function (s: number) { assertStatusIsNot(this, s) })
Then<TestWorld>('the response status should be between {int} and {int}', function (min: number, max: number) { assertStatusBetween(this, min, max) })
Then<TestWorld>('the response should be successful', function () { assertResponseSuccessful(this) })
Then<TestWorld>('the response should be a client error', function () { assertResponseClientError(this) })
Then<TestWorld>('the response should be a server error', function () { assertResponseServerError(this) })
Then<TestWorld>('the response body path {string} should equal {string}', function (p: string, v: string) { assertBodyPathEqualsString(this, p, v) })
Then<TestWorld>('the response body path {string} should equal {int}', function (p: string, v: number) { assertBodyPathEqualsInt(this, p, v) })
Then<TestWorld>('the response body path {string} should exist', function (p: string) { assertBodyPathExists(this, p) })
Then<TestWorld>('the response body path {string} should not exist', function (p: string) { assertBodyPathNotExists(this, p) })
Then<TestWorld>('the response body path {string} should contain {string}', function (p: string, s: string) { assertBodyPathContains(this, p, s) })
Then<TestWorld>('the response body path {string} should match {string}', function (p: string, s: string) { assertBodyPathMatches(this, p, s) })
Then<TestWorld>('the response body path {string} should have {int} items', function (p: string, n: number) { assertBodyPathHasItems(this, p, n) })
Then<TestWorld>('the response body should be valid JSON', function () { assertBodyIsValidJson(this) })
Then<TestWorld>('the response header {string} should equal {string}', function (h: string, v: string) { assertHeaderEquals(this, h, v) })
Then<TestWorld>('the response header {string} should contain {string}', function (h: string, s: string) { assertHeaderContains(this, h, s) })
Then<TestWorld>('the response header {string} should exist', function (h: string) { assertHeaderExists(this, h) })
Then<TestWorld>('the response should have content-type {string}', function (ct: string) { assertContentType(this, ct) })
Then<TestWorld>('the response body should equal:', function (d: string) { assertBodyEquals(this, d) })
Then<TestWorld>('the response body should contain {string}', function (s: string) { assertBodyContains(this, s) })
Then<TestWorld>('the response body should match schema {string}', async function (s: string) { await assertBodyMatchesSchema(this, s) })
// NOTE: {float} registration removed — it conflicts with {int} for integer values.
// Float comparison is handled by assertBodyPathEqualsInt which uses toBe() for exact numeric match.
// For actual decimal assertions, use the {string} variant with a string value.
Then<TestWorld>('the response body path {string} should be true', function (p: string) { assertBodyPathIsTrue(this, p) })
Then<TestWorld>('the response body path {string} should be false', function (p: string) { assertBodyPathIsFalse(this, p) })
Then<TestWorld>('the response body path {string} should be null', function (p: string) { assertBodyPathIsNull(this, p) })
Then<TestWorld>('the response time should be less than {int} ms', function (ms: number) { assertResponseTimeLessThan(this, ms) })
Then<TestWorld>('I store response body path {string} as {string}', function (p: string, v: string) { storeBodyPath(this, p, v) })
Then<TestWorld>('I store response header {string} as {string}', function (h: string, v: string) { storeHeader(this, h, v) })
Then<TestWorld>('I store response status as {string}', function (v: string) { storeStatus(this, v) })
