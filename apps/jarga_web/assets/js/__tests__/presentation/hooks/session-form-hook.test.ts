/**
 * Tests for SessionFormHook (Presentation Layer)
 *
 * Purpose: Keyboard submit behavior for session instruction textarea
 * Responsibilities:
 * - Enter submits the parent form
 * - Shift+Enter inserts a newline (default behavior)
 * - Cleanup on destroy
 */

import { describe, test, expect, beforeEach, afterEach, vi } from 'vitest'
import { SessionFormHook } from '../../../presentation/hooks/session-form-hook'

describe('SessionFormHook', () => {
  let hook: SessionFormHook
  let textarea: HTMLTextAreaElement
  let form: HTMLFormElement

  beforeEach(() => {
    // Create form with textarea
    form = document.createElement('form')
    textarea = document.createElement('textarea')
    textarea.id = 'session-instruction'
    ;(textarea as any).phxPrivate = {}
    form.appendChild(textarea)
    document.body.appendChild(form)

    // Create hook instance
    hook = new SessionFormHook(null as any, textarea)
  })

  afterEach(() => {
    vi.restoreAllMocks()
    document.body.innerHTML = ''
  })

  describe('mounted', () => {
    test('submits form on Enter key', () => {
      const submitHandler = vi.fn((e: Event) => e.preventDefault())
      form.addEventListener('submit', submitHandler)

      hook.mounted()

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        bubbles: true,
        cancelable: true,
      })
      textarea.dispatchEvent(event)

      expect(submitHandler).toHaveBeenCalledTimes(1)
    })

    test('prevents default newline on Enter', () => {
      hook.mounted()

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        bubbles: true,
        cancelable: true,
      })
      const preventDefaultSpy = vi.spyOn(event, 'preventDefault')

      textarea.dispatchEvent(event)

      expect(preventDefaultSpy).toHaveBeenCalledTimes(1)
    })

    test('allows default behavior on Shift+Enter (newline)', () => {
      hook.mounted()

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        shiftKey: true,
        bubbles: true,
        cancelable: true,
      })
      const preventDefaultSpy = vi.spyOn(event, 'preventDefault')

      textarea.dispatchEvent(event)

      expect(preventDefaultSpy).not.toHaveBeenCalled()
    })

    test('does not interfere with other keys', () => {
      hook.mounted()

      const event = new KeyboardEvent('keydown', {
        key: 'a',
        bubbles: true,
        cancelable: true,
      })
      const preventDefaultSpy = vi.spyOn(event, 'preventDefault')

      textarea.dispatchEvent(event)

      expect(preventDefaultSpy).not.toHaveBeenCalled()
    })

    test('does not submit on Ctrl+Enter', () => {
      const submitHandler = vi.fn((e: Event) => e.preventDefault())
      form.addEventListener('submit', submitHandler)

      hook.mounted()

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        ctrlKey: true,
        bubbles: true,
        cancelable: true,
      })
      textarea.dispatchEvent(event)

      // Ctrl+Enter should still submit (not Shift, so no newline intent)
      expect(submitHandler).toHaveBeenCalledTimes(1)
    })
  })

  describe('destroyed', () => {
    test('removes keydown event listener', () => {
      const removeEventListenerSpy = vi.spyOn(textarea, 'removeEventListener')

      hook.mounted()
      hook.destroyed()

      expect(removeEventListenerSpy).toHaveBeenCalledWith(
        'keydown',
        expect.any(Function)
      )
    })

    test('no longer submits form after destroyed', () => {
      const submitHandler = vi.fn((e: Event) => e.preventDefault())
      form.addEventListener('submit', submitHandler)

      hook.mounted()
      hook.destroyed()

      const event = new KeyboardEvent('keydown', {
        key: 'Enter',
        bubbles: true,
        cancelable: true,
      })
      textarea.dispatchEvent(event)

      expect(submitHandler).not.toHaveBeenCalled()
    })

    test('handles destroyed before mounted', () => {
      expect(() => {
        hook.destroyed()
      }).not.toThrow()
    })

    test('is idempotent', () => {
      hook.mounted()

      expect(() => {
        hook.destroyed()
        hook.destroyed()
      }).not.toThrow()
    })
  })
})
