/**
 * MarkdownInputRulesPlugin - Infrastructure Layer
 *
 * Adds input rules for markdown-style links and images that auto-convert as you type.
 * This enables typing:
 * - [text](url) + space → <a href="url">text</a>
 * - ![alt](url) + space → <img src="url" alt="alt">
 *
 * Infrastructure Layer Characteristics:
 * - Integrates with ProseMirror's input rule system
 * - Depends on Milkdown's link and image schemas
 * - Provides markdown shortcut conversion
 *
 * @module infrastructure/milkdown
 */

import { $inputRule } from '@milkdown/utils'
import { InputRule } from '@milkdown/prose/inputrules'

/**
 * Input rule for markdown-style links: [text](url)
 *
 * Matches patterns like:
 * - [Google](https://google.com)
 * - [Example](http://example.com "Title")
 *
 * Converts to: <a href="url" title="title">text</a>
 */
const linkInputRule = $inputRule(() => {
  // Match [text](url) or [text](url "title") followed by a space
  // The space at the end is the trigger character that activates the rule
  // Important: Use negative lookbehind to exclude image syntax ![...]
  const pattern = /(?<!!)\[(?<text>[^\]]+)\]\((?<href>[^\s)]+)(?:\s+"(?<title>[^"]+)")?\)\s$/

  return new InputRule(pattern, (state, match, start, end) => {
    const [fullMatch, text, href, title] = match
    
    if (!fullMatch) return null

    // Get link mark type from schema (link is a mark, not a node)
    const linkMarkType = state.schema.marks.link
    if (!linkMarkType) return null

    // Create link mark with href and optional title
    const attrs = { href, title: title || null }
    const mark = linkMarkType.create(attrs)

    if (!mark) return null

    // Create a transaction that:
    // 1. Deletes the entire markdown syntax (including trigger space)
    // 2. Inserts the link text
    // 3. Adds the link mark to that text
    // 4. Adds a space after WITHOUT the link mark (to "close" the link)
    // 5. Removes stored marks so future typing doesn't have the link mark
    
    const tr = state.tr
    const linkStart = start
    const linkEnd = linkStart + text.length
    
    // Delete the markdown syntax
    tr.delete(start, end)
    
    // Insert the link text
    tr.insertText(text, linkStart)
    
    // Apply the link mark to the inserted text
    tr.addMark(linkStart, linkEnd, mark)
    
    // Remove stored marks BEFORE inserting the space
    // This ensures the space is inserted without any marks
    tr.removeStoredMark(linkMarkType)
    
    // Insert a space after the link WITHOUT any marks
    tr.insertText(' ', linkEnd)

    return tr
  })
})

/**
 * Input rule for markdown-style images: ![alt](url)
 *
 * Matches patterns like:
 * - ![Image description](https://example.com/image.png)
 * - ![Alt text](https://example.com/image.png "Title")
 *
 * Converts to: <img src="url" alt="alt" title="title">
 *
 * Note: Images are NODES (not marks like links), so the implementation differs.
 * Images are inline atomic elements that cannot contain other content.
 */
const imageInputRule = $inputRule(() => {
  // Match ![alt](url) or ![alt](url "title") followed by a space
  // The space at the end is the trigger character that activates the rule
  const pattern = /!\[(?<alt>[^\]]*)\]\((?<src>[^\s)]+)(?:\s+"(?<title>[^"]+)")?\)\s$/

  return new InputRule(pattern, (state, match, start, end) => {
    const [fullMatch, alt, src, title] = match
    
    if (!fullMatch) return null

    // Get image node type from schema (image is a node, not a mark)
    const imageNodeType = state.schema.nodes.image
    if (!imageNodeType) return null

    // Create image node with src, alt, and optional title
    const attrs = { 
      src, 
      alt: alt || '', 
      title: title || null 
    }
    const imageNode = imageNodeType.create(attrs)

    if (!imageNode) return null

    // Create a transaction that:
    // 1. Deletes the entire markdown syntax (including trigger space)
    // 2. Inserts the image node
    // 3. Inserts a space after the image (so cursor doesn't stick to it)
    
    const tr = state.tr
    
    // Delete the markdown syntax
    tr.delete(start, end)
    
    // Insert the image node at the start position
    tr.insert(start, imageNode)
    
    // Insert a space after the image
    // The image node takes 1 position, so space goes at start + 1
    tr.insertText(' ', start + 1)

    return tr
  })
})

/**
 * Export both input rules as a Milkdown plugin array
 * - linkInputRule: Custom rule for [text](url) + space
 * - imageInputRule: Custom rule for ![alt](url) + space
 */
export const markdownInputRulesPlugin = [linkInputRule, imageInputRule]
