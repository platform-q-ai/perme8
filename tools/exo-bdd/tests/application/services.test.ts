import { test, expect, describe, beforeEach } from 'bun:test'
import { VariableService } from '../../src/application/services/VariableService.ts'
import { InterpolationService } from '../../src/application/services/InterpolationService.ts'
import { VariableNotFoundError } from '../../src/domain/errors/index.ts'

describe('VariableService', () => {
  // Clear shared static state between tests to ensure isolation
  beforeEach(() => {
    VariableService.clearAll()
  })
  test('set and get a variable', () => {
    const service = new VariableService()
    service.set('name', 'test')
    expect(service.get<string>('name')).toBe('test')
  })

  test('get typed variable', () => {
    const service = new VariableService()
    service.set('count', 42)
    expect(service.get<number>('count')).toBe(42)
  })

  test('throws VariableNotFoundError for missing variable', () => {
    const service = new VariableService()
    expect(() => service.get('missing')).toThrow(VariableNotFoundError)
  })

  test('has returns true for existing variable', () => {
    const service = new VariableService()
    service.set('key', 'value')
    expect(service.has('key')).toBe(true)
  })

  test('has returns false for missing variable', () => {
    const service = new VariableService()
    expect(service.has('missing')).toBe(false)
  })

  test('clear removes local variables but shared persist', () => {
    const service = new VariableService()
    service.set('a', 1)
    service.set('b', 2)
    service.clear()
    // After clear(), shared variables still accessible via has()
    expect(service.has('a')).toBe(true)
    expect(service.has('b')).toBe(true)
  })

  test('clearAll removes shared variables across instances', () => {
    const service1 = new VariableService()
    service1.set('x', 1)
    const service2 = new VariableService()
    // service2 can see service1's variable via shared store
    expect(service2.has('x')).toBe(true)
    expect(service2.get<number>('x')).toBe(1)
    // clearAll removes everything
    VariableService.clearAll()
    expect(service2.has('x')).toBe(false)
  })

  test('set overwrites existing variable', () => {
    const service = new VariableService()
    service.set('key', 'first')
    service.set('key', 'second')
    expect(service.get<string>('key')).toBe('second')
  })

  test('get with complex object value', () => {
    const service = new VariableService()
    const obj = { nested: { deep: [1, 2, 3] } }
    service.set('complex', obj)
    expect(service.get<typeof obj>('complex')).toEqual(obj)
  })

  test('get with null value', () => {
    const service = new VariableService()
    service.set('nullable', null)
    expect(service.get('nullable')).toBeNull()
  })

  test('get with undefined value', () => {
    const service = new VariableService()
    service.set('undef', undefined)
    expect(service.get('undef')).toBeUndefined()
  })

  test('has returns true after set, persists after clear, gone after clearAll', () => {
    const service = new VariableService()
    expect(service.has('lifecycle')).toBe(false)
    service.set('lifecycle', 'value')
    expect(service.has('lifecycle')).toBe(true)
    service.clear()
    // Still accessible via shared store after local clear
    expect(service.has('lifecycle')).toBe(true)
    VariableService.clearAll()
    expect(service.has('lifecycle')).toBe(false)
  })
})

describe('InterpolationService', () => {
  test('interpolates user-defined variables', () => {
    const vars = new VariableService()
    vars.set('name', 'World')
    const service = new InterpolationService(vars)
    expect(service.interpolate('Hello ${name}!')).toBe('Hello World!')
  })

  test('interpolates multiple variables', () => {
    const vars = new VariableService()
    vars.set('first', 'John')
    vars.set('last', 'Doe')
    const service = new InterpolationService(vars)
    expect(service.interpolate('${first} ${last}')).toBe('John Doe')
  })

  test('interpolates timestamp as number string', () => {
    const vars = new VariableService()
    const service = new InterpolationService(vars)
    const result = service.interpolate('${timestamp}')
    expect(Number(result)).toBeGreaterThan(0)
  })

  test('interpolates uuid as valid UUID', () => {
    const vars = new VariableService()
    const service = new InterpolationService(vars)
    const result = service.interpolate('${uuid}')
    expect(result).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)
  })

  test('interpolates random_email', () => {
    const vars = new VariableService()
    const service = new InterpolationService(vars)
    const result = service.interpolate('${random_email}')
    expect(result).toMatch(/^test_\w+@example\.com$/)
  })

  test('interpolates random_string', () => {
    const vars = new VariableService()
    const service = new InterpolationService(vars)
    const result = service.interpolate('${random_string}')
    expect(result.length).toBe(8)
  })

  test('leaves text without variables unchanged', () => {
    const vars = new VariableService()
    const service = new InterpolationService(vars)
    expect(service.interpolate('no variables here')).toBe('no variables here')
  })

  test('leaves undefined user variables uninterpolated', () => {
    const vars = new VariableService()
    const service = new InterpolationService(vars)
    expect(service.interpolate('${unknown}')).toBe('${unknown}')
  })

  test('interpolates timestamp_ms as millisecond timestamp', () => {
    const vars = new VariableService()
    const service = new InterpolationService(vars)
    const before = Date.now()
    const result = service.interpolate('${timestamp_ms}')
    const after = Date.now()
    const ms = Number(result)
    expect(ms).toBeGreaterThanOrEqual(before)
    expect(ms).toBeLessThanOrEqual(after)
  })

  test('interpolates iso_date as ISO 8601 string', () => {
    const vars = new VariableService()
    const service = new InterpolationService(vars)
    const result = service.interpolate('${iso_date}')
    expect(result).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    expect(new Date(result).toISOString()).toBe(result)
  })

  test('interpolates random_int as number between 0-999999', () => {
    const vars = new VariableService()
    const service = new InterpolationService(vars)
    const result = service.interpolate('${random_int}')
    const num = Number(result)
    expect(num).toBeGreaterThanOrEqual(0)
    expect(num).toBeLessThan(1000000)
    expect(Number.isInteger(num)).toBe(true)
  })

  test('handles adjacent variables', () => {
    const vars = new VariableService()
    vars.set('a', 'hello')
    vars.set('b', 'world')
    const service = new InterpolationService(vars)
    expect(service.interpolate('${a}${b}')).toBe('helloworld')
  })

  test('handles variables in JSON strings', () => {
    const vars = new VariableService()
    vars.set('user_id', '42')
    const service = new InterpolationService(vars)
    const result = service.interpolate('{"id": "${user_id}"}')
    expect(result).toBe('{"id": "42"}')
  })

  test('each call to uuid produces unique values', () => {
    const vars = new VariableService()
    const service = new InterpolationService(vars)
    const uuid1 = service.interpolate('${uuid}')
    const uuid2 = service.interpolate('${uuid}')
    expect(uuid1).not.toBe(uuid2)
  })

  test('each call to random_string produces unique values', () => {
    const vars = new VariableService()
    const service = new InterpolationService(vars)
    const str1 = service.interpolate('${random_string}')
    const str2 = service.interpolate('${random_string}')
    // Technically could collide but astronomically unlikely with 8 chars from 62-char alphabet
    expect(str1).not.toBe(str2)
  })
})
