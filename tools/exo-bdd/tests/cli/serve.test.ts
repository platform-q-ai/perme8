import { test, expect, describe } from 'bun:test'
import { parseServeArgs } from '../../src/cli/serve.ts'

describe('parseServeArgs', () => {
  test('defaults resultsDir to allure-results', () => {
    const opts = parseServeArgs([])
    expect(opts.resultsDir).toBe('allure-results')
  })

  test('parses --results-dir flag', () => {
    const opts = parseServeArgs(['--results-dir', 'custom-dir'])
    expect(opts.resultsDir).toBe('custom-dir')
  })

  test('ignores unknown flags', () => {
    const opts = parseServeArgs(['--unknown', 'value'])
    expect(opts.resultsDir).toBe('allure-results')
  })
})
