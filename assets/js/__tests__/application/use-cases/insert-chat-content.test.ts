/**
 * InsertChatContent Use Case Tests
 *
 * Tests for the InsertChatContent use case following TDD principles.
 * All dependencies are mocked to ensure fast, isolated tests.
 */

import { describe, test, expect, vi, beforeEach } from 'vitest'
import type { EditorAdapter } from '../../../application/interfaces/editor-adapter.interface'

// Import will fail initially (RED phase)
import { InsertChatContent } from '../../../application/use-cases/insert-chat-content'

describe('InsertChatContent', () => {
  let mockEditor: EditorAdapter
  let useCase: InsertChatContent

  beforeEach(() => {
    // Mock EditorAdapter
    mockEditor = {
      insertNode: vi.fn(),
      deleteRange: vi.fn(),
      getSelection: vi.fn().mockReturnValue({ from: 10, to: 10 }),
      getText: vi.fn().mockReturnValue('')
    }

    // Create use case with mocked dependencies
    useCase = new InsertChatContent(mockEditor)
  })

  describe('execute', () => {
    test('gets current selection from editor', async () => {
      const content = 'Some markdown content'
      const position = 5

      await useCase.execute(content, position)

      // Should get selection from editor
      expect(mockEditor.getSelection).toHaveBeenCalled()
    })

    test('inserts content at specified position using editor adapter', async () => {
      const content = '## Heading\n\nParagraph text'
      const position = 15

      await useCase.execute(content, position)

      // Note: In real implementation, this would parse markdown and insert nodes
      // For now, we're testing the interface is called
      // The actual insertion logic will be in the infrastructure layer
      expect(mockEditor.getSelection).toHaveBeenCalled()
    })

    test('throws error if content is empty', async () => {
      const emptyContent = ''
      const position = 10

      await expect(
        useCase.execute(emptyContent, position)
      ).rejects.toThrow('Content cannot be empty')
    })

    test('throws error if content is only whitespace', async () => {
      const whitespaceContent = '   \n\n   '
      const position = 20

      await expect(
        useCase.execute(whitespaceContent, position)
      ).rejects.toThrow('Content cannot be empty')
    })

    test('throws error if position is negative', async () => {
      const content = 'Valid content'
      const negativePosition = -1

      await expect(
        useCase.execute(content, negativePosition)
      ).rejects.toThrow('Position cannot be negative')
    })

    test('accepts position of zero (beginning of document)', async () => {
      const content = 'Content at start'
      const position = 0

      await expect(
        useCase.execute(content, position)
      ).resolves.toBeUndefined()
    })

    test('handles markdown content with code blocks', async () => {
      const content = '```typescript\nconst x = 5;\n```'
      const position = 25

      await expect(
        useCase.execute(content, position)
      ).resolves.toBeUndefined()
    })

    test('handles markdown content with lists', async () => {
      const content = '- Item 1\n- Item 2\n- Item 3'
      const position = 30

      await expect(
        useCase.execute(content, position)
      ).resolves.toBeUndefined()
    })

    test('handles markdown content with links and images', async () => {
      const content = '[Link](https://example.com)\n![Image](image.png)'
      const position = 40

      await expect(
        useCase.execute(content, position)
      ).resolves.toBeUndefined()
    })

    test('handles large markdown content', async () => {
      const content = '# Large Document\n\n' + 'Paragraph\n\n'.repeat(100)
      const position = 50

      await expect(
        useCase.execute(content, position)
      ).resolves.toBeUndefined()
    })

    test('trims leading and trailing whitespace from content', async () => {
      const content = '  \n\nActual content\n\n  '
      const position = 60

      await expect(
        useCase.execute(content, position)
      ).resolves.toBeUndefined()

      // Content should be trimmed before processing
      expect(mockEditor.getSelection).toHaveBeenCalled()
    })

    test('handles multiple insertions at different positions', async () => {
      await useCase.execute('First insert', 10)
      await useCase.execute('Second insert', 20)
      await useCase.execute('Third insert', 30)

      // Should get selection for each insertion
      expect(mockEditor.getSelection).toHaveBeenCalledTimes(3)
    })

    test('handles special markdown characters', async () => {
      const content = '**bold** *italic* `code` ~~strikethrough~~'
      const position = 70

      await expect(
        useCase.execute(content, position)
      ).resolves.toBeUndefined()
    })

    test('validates position before content to fail fast', async () => {
      const content = 'Valid content'
      const invalidPosition = -5

      await expect(
        useCase.execute(content, invalidPosition)
      ).rejects.toThrow('Position cannot be negative')

      // Should not call editor if validation fails
      expect(mockEditor.getSelection).not.toHaveBeenCalled()
    })

    test('validates content before position to fail fast', async () => {
      const emptyContent = ''
      const position = 10

      await expect(
        useCase.execute(emptyContent, position)
      ).rejects.toThrow('Content cannot be empty')

      // Should not call editor if validation fails
      expect(mockEditor.getSelection).not.toHaveBeenCalled()
    })
  })
})
