import { describe, test, expect } from 'vitest'

/**
 * Unit tests for markdown input rules plugin
 * 
 * These tests verify:
 * 1. Link pattern matching (with negative lookbehind)
 * 2. Image pattern matching
 * 3. Edge cases and special characters
 * 4. Pattern mutual exclusivity
 */
describe('Markdown Input Rules - Pattern Matching', () => {
  // Link pattern: /(?<!!)\[(?<text>[^\]]+)\]\((?<href>[^\s)]+)(?:\s+"(?<title>[^"]+)")?\)\s$/
  const linkPattern = /(?<!!)\[(?<text>[^\]]+)\]\((?<href>[^\s)]+)(?:\s+"(?<title>[^"]+)")?\)\s$/

  // Image pattern: /!\[(?<alt>[^\]]*)\]\((?<src>[^\s)]+)(?:\s+"(?<title>[^"]+)")?\)\s$/
  const imagePattern = /!\[(?<alt>[^\]]*)\]\((?<src>[^\s)]+)(?:\s+"(?<title>[^"]+)")?\)\s$/

  describe('Link Pattern', () => {
    test('matches simple link with trailing space', () => {
      const text = '[Google](https://google.com) '
      const match = text.match(linkPattern)
      
      expect(match).not.toBeNull()
      expect(match![1]).toBe('Google')
      expect(match![2]).toBe('https://google.com')
    })

    test('matches link with title attribute', () => {
      const text = '[Google](https://google.com "Search Engine") '
      const match = text.match(linkPattern)
      
      expect(match).not.toBeNull()
      expect(match![1]).toBe('Google')
      expect(match![2]).toBe('https://google.com')
      expect(match![3]).toBe('Search Engine')
    })

    test('matches link with complex text', () => {
      const text = '[Click here to visit!](https://example.com) '
      const match = text.match(linkPattern)
      
      expect(match).not.toBeNull()
      expect(match![1]).toBe('Click here to visit!')
    })

    test('matches link with special characters in URL', () => {
      const text = '[API Docs](https://api.example.com/v1/users?sort=name&limit=10) '
      const match = text.match(linkPattern)
      
      expect(match).not.toBeNull()
      expect(match![2]).toBe('https://api.example.com/v1/users?sort=name&limit=10')
    })

    test('does NOT match link without trailing space', () => {
      const text = '[Google](https://google.com)'
      const match = text.match(linkPattern)
      
      expect(match).toBeNull()
    })

    test('does NOT match image syntax (negative lookbehind)', () => {
      const text = '![Alt text](https://example.com/image.png) '
      const match = text.match(linkPattern)
      
      expect(match).toBeNull()
    })

    test('does NOT match when text is empty', () => {
      const text = '[](https://google.com) '
      const match = text.match(linkPattern)
      
      expect(match).toBeNull()
    })

    test('does NOT match when URL contains spaces', () => {
      const text = '[Google](https://google.com with spaces) '
      const match = text.match(linkPattern)
      
      // Should only match up to the first space
      if (match) {
        expect(match[2]).not.toContain(' ')
      }
    })
  })

  describe('Image Pattern', () => {
    test('matches simple image with trailing space', () => {
      const text = '![Cat](https://example.com/cat.png) '
      const match = text.match(imagePattern)
      
      expect(match).not.toBeNull()
      expect(match![1]).toBe('Cat')
      expect(match![2]).toBe('https://example.com/cat.png')
    })

    test('matches image with title attribute', () => {
      const text = '![Cat](https://example.com/cat.png "A cute cat") '
      const match = text.match(imagePattern)
      
      expect(match).not.toBeNull()
      expect(match![1]).toBe('Cat')
      expect(match![2]).toBe('https://example.com/cat.png')
      expect(match![3]).toBe('A cute cat')
    })

    test('matches image with empty alt text', () => {
      const text = '![](https://example.com/image.png) '
      const match = text.match(imagePattern)
      
      expect(match).not.toBeNull()
      expect(match![1]).toBe('')
      expect(match![2]).toBe('https://example.com/image.png')
    })

    test('matches image with complex alt text', () => {
      const text = '![A photo of my cat, Mr. Whiskers!](https://example.com/cat.png) '
      const match = text.match(imagePattern)
      
      expect(match).not.toBeNull()
      expect(match![1]).toBe('A photo of my cat, Mr. Whiskers!')
    })

    test('matches image with special characters in URL', () => {
      const text = '![Image](https://cdn.example.com/images/photo_2024.png?size=large&format=webp) '
      const match = text.match(imagePattern)
      
      expect(match).not.toBeNull()
      expect(match![2]).toBe('https://cdn.example.com/images/photo_2024.png?size=large&format=webp')
    })

    test('does NOT match image without trailing space', () => {
      const text = '![Cat](https://example.com/cat.png)'
      const match = text.match(imagePattern)
      
      expect(match).toBeNull()
    })

    test('does NOT match link syntax (no exclamation mark)', () => {
      const text = '[Google](https://google.com) '
      const match = text.match(imagePattern)
      
      expect(match).toBeNull()
    })

    test('does NOT match when URL contains spaces', () => {
      const text = '![Image](https://example.com/image with spaces.png) '
      const match = text.match(imagePattern)
      
      // Should only match up to the first space
      if (match) {
        expect(match[2]).not.toContain(' ')
      }
    })
  })

  describe('Pattern Mutual Exclusivity', () => {
    test('link pattern does not match image syntax', () => {
      const imageText = '![Cat](https://example.com/cat.png) '
      
      const linkMatch = imageText.match(linkPattern)
      const imageMatch = imageText.match(imagePattern)
      
      expect(linkMatch).toBeNull()
      expect(imageMatch).not.toBeNull()
    })

    test('image pattern does not match link syntax', () => {
      const linkText = '[Google](https://google.com) '
      
      const linkMatch = linkText.match(linkPattern)
      const imageMatch = linkText.match(imagePattern)
      
      expect(linkMatch).not.toBeNull()
      expect(imageMatch).toBeNull()
    })

    test('both patterns require trailing space', () => {
      const linkTextNoSpace = '[Google](https://google.com)'
      const imageTextNoSpace = '![Cat](https://example.com/cat.png)'
      
      expect(linkTextNoSpace.match(linkPattern)).toBeNull()
      expect(imageTextNoSpace.match(imagePattern)).toBeNull()
    })
  })

  describe('Edge Cases', () => {
    test('handles nested brackets in link text', () => {
      const text = '[Array[0]](https://example.com) '
      const match = text.match(linkPattern)
      
      // Pattern doesn't support nested brackets (by design)
      // The [^\]]+ will stop at first ]
      expect(match).toBeNull()
    })

    test('handles markdown in link text', () => {
      const text = '[**Bold Link**](https://example.com) '
      const match = text.match(linkPattern)
      
      expect(match).not.toBeNull()
      expect(match![1]).toBe('**Bold Link**')
    })

    test('handles URLs with fragments', () => {
      const text = '[Section](https://example.com/page#section) '
      const match = text.match(linkPattern)
      
      expect(match).not.toBeNull()
      expect(match![2]).toBe('https://example.com/page#section')
    })

    test('handles relative URLs in links', () => {
      const text = '[Home](/home) '
      const match = text.match(linkPattern)
      
      expect(match).not.toBeNull()
      expect(match![2]).toBe('/home')
    })

    test('handles relative URLs in images', () => {
      const text = '![Logo](/assets/logo.png) '
      const match = text.match(imagePattern)
      
      expect(match).not.toBeNull()
      expect(match![2]).toBe('/assets/logo.png')
    })

    test('handles mailto links', () => {
      const text = '[Email](mailto:test@example.com) '
      const match = text.match(linkPattern)
      
      expect(match).not.toBeNull()
      expect(match![2]).toBe('mailto:test@example.com')
    })
  })
})
