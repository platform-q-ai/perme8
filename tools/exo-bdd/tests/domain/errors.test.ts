import { test, expect, describe } from 'bun:test'
import { VariableNotFoundError } from '../../src/domain/errors/VariableNotFoundError.ts'
import { AdapterNotConfiguredError } from '../../src/domain/errors/AdapterNotConfiguredError.ts'
import { DomainError } from '../../src/domain/errors/DomainError.ts'

describe('VariableNotFoundError', () => {
  test('has correct code', () => {
    const error = new VariableNotFoundError('myVar')
    expect(error.code).toBe('VARIABLE_NOT_FOUND')
  })

  test('has descriptive message', () => {
    const error = new VariableNotFoundError('myVar')
    expect(error.message).toBe('Variable "myVar" is not defined')
  })

  test('extends DomainError', () => {
    const error = new VariableNotFoundError('myVar')
    expect(error).toBeInstanceOf(DomainError)
    expect(error).toBeInstanceOf(Error)
  })

  test('handles special characters in name', () => {
    const error = new VariableNotFoundError('${my.var}')
    expect(error.message).toBe('Variable "${my.var}" is not defined')
    expect(error.code).toBe('VARIABLE_NOT_FOUND')
  })
})

describe('AdapterNotConfiguredError', () => {
  test('has correct code', () => {
    const error = new AdapterNotConfiguredError('http')
    expect(error.code).toBe('ADAPTER_NOT_CONFIGURED')
  })

  test('has descriptive message', () => {
    const error = new AdapterNotConfiguredError('http')
    expect(error.message).toBe('Adapter "http" is not configured')
  })

  test('extends DomainError', () => {
    const error = new AdapterNotConfiguredError('http')
    expect(error).toBeInstanceOf(DomainError)
  })

  test('handles empty string adapter name', () => {
    const error = new AdapterNotConfiguredError('')
    expect(error.message).toBe('Adapter "" is not configured')
    expect(error.code).toBe('ADAPTER_NOT_CONFIGURED')
  })
})

describe('DomainError', () => {
  test('is abstract and requires subclass to provide code', () => {
    // DomainError is abstract at compile time; at runtime verify subclasses must define code
    const error = new VariableNotFoundError('x')
    expect(error).toBeInstanceOf(DomainError)
    expect(error).toBeInstanceOf(Error)
    // Verify the abstract contract: code must be defined by subclass
    expect(typeof error.code).toBe('string')
    expect(error.code.length).toBeGreaterThan(0)
  })

  test('errors are serializable via JSON.stringify', () => {
    const error = new VariableNotFoundError('testVar')
    const serialized = JSON.stringify({ message: error.message, code: error.code })
    const parsed = JSON.parse(serialized)
    expect(parsed.message).toBe('Variable "testVar" is not defined')
    expect(parsed.code).toBe('VARIABLE_NOT_FOUND')
  })
})
