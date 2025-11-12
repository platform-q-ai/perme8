/**
 * LocalStorageAdapter
 *
 * Wraps browser localStorage API with error handling for:
 * - QuotaExceededError (storage full)
 * - SecurityError (storage disabled/blocked)
 * - General storage exceptions
 */
export class LocalStorageAdapter {
  /**
   * Retrieves value from localStorage
   * @param key - Storage key
   * @returns Value if found, null otherwise
   */
  get(key: string): string | null {
    try {
      return localStorage.getItem(key)
    } catch (error) {
      console.error('LocalStorage get error:', error)
      return null
    }
  }

  /**
   * Stores value in localStorage
   * @param key - Storage key
   * @param value - Value to store
   */
  set(key: string, value: string): void {
    try {
      localStorage.setItem(key, value)
    } catch (error) {
      console.error('LocalStorage set error:', error)
    }
  }

  /**
   * Removes key from localStorage
   * @param key - Storage key to remove
   */
  remove(key: string): void {
    try {
      localStorage.removeItem(key)
    } catch (error) {
      console.error('LocalStorage remove error:', error)
    }
  }

  /**
   * Clears all localStorage data
   */
  clear(): void {
    try {
      localStorage.clear()
    } catch (error) {
      console.error('LocalStorage clear error:', error)
    }
  }

  /**
   * Checks if key exists in localStorage
   * @param key - Storage key
   * @returns True if key exists, false otherwise
   */
  has(key: string): boolean {
    try {
      return localStorage.getItem(key) !== null
    } catch (error) {
      console.error('LocalStorage has error:', error)
      return false
    }
  }
}
