import { describe, test, expect, vi, beforeEach } from 'vitest'
import { InsertMarkdownContent } from '../../../application/use-cases/insert-markdown-content'
import type { IMarkdownContentInserter } from '../../../application/interfaces/markdown-content-inserter'

describe('InsertMarkdownContent', () => {
  let mockInserter: IMarkdownContentInserter
  let useCase: InsertMarkdownContent

  beforeEach(() => {
    mockInserter = {
      insertMarkdown: vi.fn()
    }

    useCase = new InsertMarkdownContent(mockInserter)
  })

  describe('execute', () => {
    test('inserts markdown content using inserter', () => {
      const markdown = '# Heading\n\nParagraph text'

      useCase.execute({ markdown })

      expect(mockInserter.insertMarkdown).toHaveBeenCalledWith(markdown)
    })

    test('does nothing when markdown is empty string', () => {
      useCase.execute({ markdown: '' })

      expect(mockInserter.insertMarkdown).not.toHaveBeenCalled()
    })

    test('does nothing when markdown is only whitespace', () => {
      useCase.execute({ markdown: '   \n\t  ' })

      expect(mockInserter.insertMarkdown).not.toHaveBeenCalled()
    })

    test('inserts markdown with leading/trailing whitespace', () => {
      const markdown = '  # Heading  '

      useCase.execute({ markdown })

      expect(mockInserter.insertMarkdown).toHaveBeenCalledWith(markdown)
    })

    test('inserts complex markdown content', () => {
      const markdown = `# Title

## Subtitle

- List item 1
- List item 2

\`\`\`javascript
const code = 'example'
\`\`\`

**Bold** and *italic* text.`

      useCase.execute({ markdown })

      expect(mockInserter.insertMarkdown).toHaveBeenCalledWith(markdown)
    })

    test('logs warning when markdown is empty', () => {
      const consoleSpy = vi.spyOn(console, 'warn').mockImplementation(() => {})

      useCase.execute({ markdown: '' })

      expect(consoleSpy).toHaveBeenCalledWith(
        '[InsertMarkdownContent] Empty markdown, skipping insertion'
      )

      consoleSpy.mockRestore()
    })
  })
})
