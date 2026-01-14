/**
 * Logger Utility
 *
 * Provides consistent logging patterns across the application.
 * All logs are prefixed with the module name for easy debugging and filtering.
 *
 * @module infrastructure/browser
 */

/**
 * Log levels
 */
export enum LogLevel {
  ERROR = 'error',
  WARN = 'warn',
  INFO = 'info',
  DEBUG = 'debug'
}

/**
 * Logger configuration
 */
interface LoggerConfig {
  /** Minimum log level to output (default: INFO in production, DEBUG in development) */
  minLevel?: LogLevel
  /** Whether to include timestamps (default: false) */
  includeTimestamp?: boolean
}

/**
 * Logger instance
 */
class Logger {
  private config: LoggerConfig = {
    minLevel: process.env.NODE_ENV === 'production' ? LogLevel.INFO : LogLevel.DEBUG,
    includeTimestamp: false
  }

  /**
   * Configure the logger
   */
  configure(config: Partial<LoggerConfig>): void {
    this.config = { ...this.config, ...config }
  }

  /**
   * Log an error message
   *
   * @param module - Module name (e.g., 'MilkdownEditorHook', 'AgentAssistantOrchestrator')
   * @param message - Error message
   * @param error - Optional error object or additional context
   *
   * @example
   * ```typescript
   * logger.error('MilkdownEditorHook', 'Failed to initialize editor', error)
   * // Output: [MilkdownEditorHook] Failed to initialize editor Error: ...
   * ```
   */
  error(module: string, message: string, error?: any): void {
    if (this.shouldLog(LogLevel.ERROR)) {
      const prefix = this.formatPrefix(module, LogLevel.ERROR)
      if (error !== undefined) {
        console.error(prefix, message, error)
      } else {
        console.error(prefix, message)
      }
    }
  }

  /**
   * Log a warning message
   *
   * @param module - Module name
   * @param message - Warning message
   *
   * @example
   * ```typescript
   * logger.warn('MilkdownEditorHook', 'Cannot setup agent assistance without adapters')
   * // Output: [MilkdownEditorHook] Cannot setup agent assistance without adapters
   * ```
   */
  warn(module: string, message: string): void {
    if (this.shouldLog(LogLevel.WARN)) {
      const prefix = this.formatPrefix(module, LogLevel.WARN)
      console.warn(prefix, message)
    }
  }

  /**
   * Log an info message
   *
   * @param module - Module name
   * @param message - Info message
   *
   * @example
   * ```typescript
   * logger.info('CollaborationSession', 'User joined session')
   * // Output: [CollaborationSession] User joined session
   * ```
   */
  info(module: string, message: string): void {
    if (this.shouldLog(LogLevel.INFO)) {
      const prefix = this.formatPrefix(module, LogLevel.INFO)
      console.info(prefix, message)
    }
  }

  /**
   * Log a debug message
   *
   * @param module - Module name
   * @param message - Debug message
   * @param data - Optional data to log
   *
   * @example
   * ```typescript
   * logger.debug('YjsDocumentAdapter', 'Applying remote update', { updateSize: update.length })
   * // Output: [YjsDocumentAdapter] Applying remote update { updateSize: 1234 }
   * ```
   */
  debug(module: string, message: string, data?: any): void {
    if (this.shouldLog(LogLevel.DEBUG)) {
      const prefix = this.formatPrefix(module, LogLevel.DEBUG)
      if (data !== undefined) {
        console.debug(prefix, message, data)
      } else {
        console.debug(prefix, message)
      }
    }
  }

  /**
   * Format the log prefix
   */
  private formatPrefix(module: string, _level: LogLevel): string {
    const timestamp = this.config.includeTimestamp ? `${new Date().toISOString()} ` : ''
    return `${timestamp}[${module}]`
  }

  /**
   * Check if a log level should be output
   */
  private shouldLog(level: LogLevel): boolean {
    const levels = [LogLevel.DEBUG, LogLevel.INFO, LogLevel.WARN, LogLevel.ERROR]
    const minLevelIndex = levels.indexOf(this.config.minLevel || LogLevel.INFO)
    const currentLevelIndex = levels.indexOf(level)
    return currentLevelIndex >= minLevelIndex
  }
}

/**
 * Singleton logger instance
 */
export const logger = new Logger()
