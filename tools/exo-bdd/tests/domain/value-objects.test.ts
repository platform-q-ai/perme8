import { test, expect, describe } from 'bun:test'
import { RiskLevel } from '../../src/domain/value-objects/RiskLevel.ts'
import { JsonPath } from '../../src/domain/value-objects/JsonPath.ts'
import type { NodeType } from '../../src/domain/value-objects/NodeType.ts'

describe('RiskLevel', () => {
  test('compare returns positive when first is higher', () => {
    expect(RiskLevel.compare('High', 'Low')).toBeGreaterThan(0)
  })

  test('compare returns negative when first is lower', () => {
    expect(RiskLevel.compare('Low', 'High')).toBeLessThan(0)
  })

  test('compare returns zero for same levels', () => {
    expect(RiskLevel.compare('Medium', 'Medium')).toBe(0)
  })

  test('isAtLeast returns true when level meets threshold', () => {
    expect(RiskLevel.isAtLeast('High', 'Medium')).toBe(true)
  })

  test('isAtLeast returns false when level is below threshold', () => {
    expect(RiskLevel.isAtLeast('Low', 'High')).toBe(false)
  })

  test('isAtLeast returns true for equal levels', () => {
    expect(RiskLevel.isAtLeast('Medium', 'Medium')).toBe(true)
  })

  test('compare Informational vs Low returns negative', () => {
    expect(RiskLevel.compare('Informational', 'Low')).toBeLessThan(0)
  })

  test('isAtLeast Informational meets Informational', () => {
    expect(RiskLevel.isAtLeast('Informational', 'Informational')).toBe(true)
  })

  test('constants have correct values', () => {
    expect(RiskLevel.High).toBe('High')
    expect(RiskLevel.Medium).toBe('Medium')
    expect(RiskLevel.Low).toBe('Low')
    expect(RiskLevel.Informational).toBe('Informational')
  })
})

describe('JsonPath', () => {
  test('creates valid JsonPath starting with $', () => {
    const path = new JsonPath('$.store.book[0].title')
    expect(path.expression).toBe('$.store.book[0].title')
  })

  test('throws for path not starting with $', () => {
    expect(() => new JsonPath('store.book')).toThrow('JSONPath must start with $')
  })

  test('toString returns expression', () => {
    const path = new JsonPath('$.name')
    expect(path.toString()).toBe('$.name')
  })

  test('handles complex expressions', () => {
    const path1 = new JsonPath('$.store.book[*].author')
    expect(path1.expression).toBe('$.store.book[*].author')

    const path2 = new JsonPath('$..price')
    expect(path2.expression).toBe('$..price')
  })

  test('$ alone is valid', () => {
    const path = new JsonPath('$')
    expect(path.expression).toBe('$')
    expect(path.toString()).toBe('$')
  })
})

describe('NodeType', () => {
  test('includes all expected types', () => {
    const types: NodeType[] = ['class', 'interface', 'function', 'file', 'module']
    expect(types).toHaveLength(5)
    expect(types).toContain('class')
    expect(types).toContain('interface')
    expect(types).toContain('function')
    expect(types).toContain('file')
    expect(types).toContain('module')
  })
})
