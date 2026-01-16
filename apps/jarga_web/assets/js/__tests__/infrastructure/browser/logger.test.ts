/**
 * Tests for Logger utility
 */

import { describe, test, expect, beforeEach, afterEach, vi } from 'vitest'
import { logger, LogLevel } from '../../../infrastructure/browser/logger'

describe('Logger', () => {
  // Spy on console methods
  let consoleErrorSpy: any
  let consoleWarnSpy: any
  let consoleInfoSpy: any
  let consoleDebugSpy: any

  beforeEach(() => {
    consoleErrorSpy = vi.spyOn(console, 'error').mockImplementation(() => {})
    consoleWarnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})
    consoleInfoSpy = vi.spyOn(console, 'info').mockImplementation(() => {})
    consoleDebugSpy = vi.spyOn(console, 'debug').mockImplementation(() => {})

    // Reset logger configuration to defaults before each test
    logger.configure({
      minLevel: LogLevel.DEBUG,
      includeTimestamp: false
    })
  })

  afterEach(() => {
    consoleErrorSpy.mockRestore()
    consoleWarnSpy.mockRestore()
    consoleInfoSpy.mockRestore()
    consoleDebugSpy.mockRestore()
  })

  describe('error', () => {
    test('logs error messages with module prefix', () => {
      logger.error('TestModule', 'Something went wrong')

      expect(consoleErrorSpy).toHaveBeenCalledWith('[TestModule]', 'Something went wrong')
    })

    test('logs error messages with error object', () => {
      const error = new Error('Test error')
      logger.error('TestModule', 'Operation failed', error)

      expect(consoleErrorSpy).toHaveBeenCalledWith('[TestModule]', 'Operation failed', error)
    })
  })

  describe('warn', () => {
    test('logs warning messages with module prefix', () => {
      logger.warn('TestModule', 'This is a warning')

      expect(consoleWarnSpy).toHaveBeenCalledWith('[TestModule]', 'This is a warning')
    })
  })

  describe('info', () => {
    test('logs info messages with module prefix', () => {
      logger.info('TestModule', 'Informational message')

      expect(consoleInfoSpy).toHaveBeenCalledWith('[TestModule]', 'Informational message')
    })
  })

  describe('debug', () => {
    test('logs debug messages with module prefix', () => {
      logger.debug('TestModule', 'Debug information')

      expect(consoleDebugSpy).toHaveBeenCalledWith('[TestModule]', 'Debug information')
    })

    test('logs debug messages with data', () => {
      const data = { key: 'value', count: 42 }
      logger.debug('TestModule', 'Debug with data', data)

      expect(consoleDebugSpy).toHaveBeenCalledWith('[TestModule]', 'Debug with data', data)
    })
  })

  describe('log level filtering', () => {
    test('respects minimum log level - ERROR', () => {
      logger.configure({ minLevel: LogLevel.ERROR })

      logger.debug('TestModule', 'debug message')
      logger.info('TestModule', 'info message')
      logger.warn('TestModule', 'warn message')
      logger.error('TestModule', 'error message')

      expect(consoleDebugSpy).not.toHaveBeenCalled()
      expect(consoleInfoSpy).not.toHaveBeenCalled()
      expect(consoleWarnSpy).not.toHaveBeenCalled()
      expect(consoleErrorSpy).toHaveBeenCalledWith('[TestModule]', 'error message')
    })

    test('respects minimum log level - WARN', () => {
      logger.configure({ minLevel: LogLevel.WARN })

      logger.debug('TestModule', 'debug message')
      logger.info('TestModule', 'info message')
      logger.warn('TestModule', 'warn message')
      logger.error('TestModule', 'error message')

      expect(consoleDebugSpy).not.toHaveBeenCalled()
      expect(consoleInfoSpy).not.toHaveBeenCalled()
      expect(consoleWarnSpy).toHaveBeenCalledWith('[TestModule]', 'warn message')
      expect(consoleErrorSpy).toHaveBeenCalledWith('[TestModule]', 'error message')
    })

    test('respects minimum log level - INFO', () => {
      logger.configure({ minLevel: LogLevel.INFO })

      logger.debug('TestModule', 'debug message')
      logger.info('TestModule', 'info message')
      logger.warn('TestModule', 'warn message')
      logger.error('TestModule', 'error message')

      expect(consoleDebugSpy).not.toHaveBeenCalled()
      expect(consoleInfoSpy).toHaveBeenCalledWith('[TestModule]', 'info message')
      expect(consoleWarnSpy).toHaveBeenCalledWith('[TestModule]', 'warn message')
      expect(consoleErrorSpy).toHaveBeenCalledWith('[TestModule]', 'error message')
    })

    test('respects minimum log level - DEBUG', () => {
      logger.configure({ minLevel: LogLevel.DEBUG })

      logger.debug('TestModule', 'debug message')
      logger.info('TestModule', 'info message')
      logger.warn('TestModule', 'warn message')
      logger.error('TestModule', 'error message')

      expect(consoleDebugSpy).toHaveBeenCalledWith('[TestModule]', 'debug message')
      expect(consoleInfoSpy).toHaveBeenCalledWith('[TestModule]', 'info message')
      expect(consoleWarnSpy).toHaveBeenCalledWith('[TestModule]', 'warn message')
      expect(consoleErrorSpy).toHaveBeenCalledWith('[TestModule]', 'error message')
    })
  })

  describe('configuration', () => {
    test('can enable timestamps', () => {
      logger.configure({ includeTimestamp: true })

      logger.info('TestModule', 'With timestamp')

      // Check that the prefix includes a timestamp (ISO format)
      const callArgs = consoleInfoSpy.mock.calls[0]
      expect(callArgs[0]).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z \[TestModule\]$/)
    })

    test('timestamps are disabled by default', () => {
      logger.info('TestModule', 'Without timestamp')

      expect(consoleInfoSpy).toHaveBeenCalledWith('[TestModule]', 'Without timestamp')
    })
  })

  describe('module names', () => {
    test('handles different module name formats', () => {
      logger.error('MilkdownEditorHook', 'Error in hook')
      logger.warn('AgentAssistantOrchestrator', 'Warning in orchestrator')
      logger.info('YjsDocumentAdapter', 'Info in adapter')

      expect(consoleErrorSpy).toHaveBeenCalledWith('[MilkdownEditorHook]', 'Error in hook')
      expect(consoleWarnSpy).toHaveBeenCalledWith('[AgentAssistantOrchestrator]', 'Warning in orchestrator')
      expect(consoleInfoSpy).toHaveBeenCalledWith('[YjsDocumentAdapter]', 'Info in adapter')
    })
  })

  describe('error handling', () => {
    test('handles undefined error parameter gracefully', () => {
      logger.error('TestModule', 'Error without details', undefined)

      // When error is undefined, it's not included in the call
      expect(consoleErrorSpy).toHaveBeenCalledWith('[TestModule]', 'Error without details')
    })

    test('handles null data parameter gracefully', () => {
      logger.debug('TestModule', 'Debug without data', null)

      expect(consoleDebugSpy).toHaveBeenCalledWith('[TestModule]', 'Debug without data', null)
    })
  })
})
