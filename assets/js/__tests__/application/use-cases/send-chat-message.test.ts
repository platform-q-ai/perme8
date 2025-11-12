/**
 * SendChatMessage Use Case Tests
 *
 * Tests for the SendChatMessage use case following TDD principles.
 * All dependencies are mocked to ensure fast, isolated tests.
 */

import { describe, test, expect, vi, beforeEach } from 'vitest'
import type { LiveViewBridge } from '../../../application/interfaces/liveview-bridge.interface'

// Import will fail initially (RED phase)
import { SendChatMessage } from '../../../application/use-cases/send-chat-message'

describe('SendChatMessage', () => {
  let mockBridge: LiveViewBridge
  let useCase: SendChatMessage

  beforeEach(() => {
    // Mock LiveViewBridge
    mockBridge = {
      pushEvent: vi.fn().mockResolvedValue(undefined),
      handleEvent: vi.fn()
    }

    // Create use case with mocked dependencies
    useCase = new SendChatMessage(mockBridge)
  })

  describe('execute', () => {
    test('sends chat message to LiveView server with correct payload', async () => {
      const message = 'Hello, world!'
      const userId = 'user-123'

      await useCase.execute(message, userId)

      // Should push event to server
      expect(mockBridge.pushEvent).toHaveBeenCalledWith(
        'chat_message',
        expect.objectContaining({
          message: 'Hello, world!',
          user_id: 'user-123'
        })
      )
    })

    test('trims whitespace from message before sending', async () => {
      const message = '  Hello with spaces  '
      const userId = 'user-456'

      await useCase.execute(message, userId)

      // Should trim whitespace
      expect(mockBridge.pushEvent).toHaveBeenCalledWith(
        'chat_message',
        expect.objectContaining({
          message: 'Hello with spaces'
        })
      )
    })

    test('throws error if message is empty', async () => {
      const emptyMessage = ''
      const userId = 'user-789'

      await expect(
        useCase.execute(emptyMessage, userId)
      ).rejects.toThrow('Message cannot be empty')
    })

    test('throws error if message is only whitespace', async () => {
      const whitespaceMessage = '   '
      const userId = 'user-999'

      await expect(
        useCase.execute(whitespaceMessage, userId)
      ).rejects.toThrow('Message cannot be empty')
    })

    test('throws error if user ID is empty', async () => {
      const message = 'Valid message'
      const emptyUserId = ''

      await expect(
        useCase.execute(message, emptyUserId)
      ).rejects.toThrow('User ID cannot be empty')
    })

    test('handles messages with special characters', async () => {
      const message = 'Message with @mentions and #hashtags!'
      const userId = 'user-special'

      await useCase.execute(message, userId)

      expect(mockBridge.pushEvent).toHaveBeenCalledWith(
        'chat_message',
        expect.objectContaining({
          message: 'Message with @mentions and #hashtags!'
        })
      )
    })

    test('handles multiline messages', async () => {
      const message = 'Line 1\nLine 2\nLine 3'
      const userId = 'user-multiline'

      await useCase.execute(message, userId)

      expect(mockBridge.pushEvent).toHaveBeenCalledWith(
        'chat_message',
        expect.objectContaining({
          message: 'Line 1\nLine 2\nLine 3'
        })
      )
    })

    test('handles long messages without truncation', async () => {
      const longMessage = 'a'.repeat(1000)
      const userId = 'user-long'

      await useCase.execute(longMessage, userId)

      expect(mockBridge.pushEvent).toHaveBeenCalledWith(
        'chat_message',
        expect.objectContaining({
          message: longMessage
        })
      )
    })

    test('sends multiple messages sequentially', async () => {
      const userId = 'user-multiple'

      await useCase.execute('First message', userId)
      await useCase.execute('Second message', userId)
      await useCase.execute('Third message', userId)

      expect(mockBridge.pushEvent).toHaveBeenCalledTimes(3)

      const calls = vi.mocked(mockBridge.pushEvent).mock.calls
      expect(calls[0][1].message).toBe('First message')
      expect(calls[1][1].message).toBe('Second message')
      expect(calls[2][1].message).toBe('Third message')
    })

    test('preserves message content exactly after trimming', async () => {
      const message = '  Code example: const x = 5;  '
      const userId = 'user-code'

      await useCase.execute(message, userId)

      expect(mockBridge.pushEvent).toHaveBeenCalledWith(
        'chat_message',
        expect.objectContaining({
          message: 'Code example: const x = 5;'
        })
      )
    })
  })
})
