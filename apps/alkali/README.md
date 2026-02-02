# Alkali

A fast, modern static site generator built with Elixir. Perfect for blogs, documentation sites, and marketing pages.

## Features

- **Markdown Content** - Write your content in Markdown with YAML frontmatter
- **EEx Templates** - Powerful templating with Elixir's built-in EEx
- **Collections** - Automatic tag and category pages
- **Asset Pipeline** - Automatic minification and fingerprinting for CSS/JS
- **Incremental Builds** - Only rebuild changed files for lightning-fast builds
- **Clean Architecture** - Well-tested, maintainable codebase following SOLID principles

## Quick Start

### Installation

Add `alkali` to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:alkali, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

### Tutorial: Creating Your First Site

Here's a complete walkthrough of creating, building, and adding content to a site:

#### 1. Create a New Site

```bash
# Create a new site called "my_blog"
mix alkali.new my_blog

# Change into the site directory
cd my_blog
```

This creates a new site with the following structure:

```
my_blog/
├── config/
│   └── alkali.exs        # Site configuration
├── content/
│   ├── posts/            # Your blog posts
│   │   └── 2024-01-15-hello-world.md
│   └── pages/            # Static pages
│       └── about.md
├── layouts/
│   ├── default.html.heex # Default layout
│   ├── post.html.heex    # Post layout
│   ├── page.html.heex    # Page layout
│   └── partials/         # Reusable partials
│       ├── nav.html
│       └── footer.html
├── static/
│   ├── css/
│   │   └── app.css
│   └── js/
│       └── app.js
└── _site/                # Generated output (created on build)
```

#### 2. Configure Your Site

Edit `config/alkali.exs` to customize your site:

```elixir
import Config

config :alkali,
  site: %{
    title: "My Awesome Blog",
    url: "https://myblog.com",
    author: "Your Name",
    description: "A blog about Elixir and web development"
  }
```

#### 3. Build Your Site

```bash
# Build the site (generates files in _site/)
mix alkali.build

# Build with verbose output to see what's happening
mix alkali.build --verbose

# Build including draft posts
mix alkali.build --draft

# Clean and rebuild everything
mix alkali.build --clean
```

Your static site is now generated in the `_site/` directory!

#### 4. View Your Site Locally

```bash
# Serve the _site/ directory with any static server
# For example, using Python:
cd _site && python3 -m http.server 8000

# Or using Elixir:
cd _site && mix run -e 'Mix.Tasks.Run.run([])' -- --no-halt
```

Visit `http://localhost:8000` to see your site!

#### 5. Development Workflow

```bash
# Make changes to content or layouts
vim content/posts/2024-01-15-hello-world.md

# Rebuild (only changed files are rebuilt)
mix alkali.build

# Clear cache and force full rebuild if needed
rm .alkali_cache.json
mix alkali.build
```

## Usage

### Creating Content

Create a new post in `content/posts/`:

```bash
mix alkali.post "My First Post"
```

This creates a file like `content/posts/2024-01-15-my-first-post.md`:

```markdown
---
title: My First Post
date: 2024-01-15
tags: [elixir, blog]
category: technology
layout: post
draft: false
---

# My First Post

This is my first post! You can write **Markdown** here.

- Lists work
- So do [links](https://example.com)
- And code blocks

\`\`\`elixir
defmodule Hello do
def world, do: "Hello, World!"
end
\`\`\`
```

### Frontmatter Fields

| Field      | Required | Description                                 |
| ---------- | -------- | ------------------------------------------- |
| `title`    | Yes      | Post title                                  |
| `date`     | Yes      | Publication date (ISO 8601 format)          |
| `layout`   | No       | Layout template to use (default: "default") |
| `tags`     | No       | List of tags for categorization             |
| `category` | No       | Single category                             |
| `draft`    | No       | If true, post is hidden (default: false)    |

### Layouts

Layouts are EEx templates in the `layouts/` directory:

```heex
<!DOCTYPE html>
<html>
  <head>
    <title><%= @page.title %> - <%= @site[:site_name] %></title>
    <link rel="stylesheet" href="/css/app.css">
  </head>
  <body>
    <header>
      <h1><%= @site[:site_name] %></h1>
    </header>

    <main>
      <%= @content %>
    </main>

    <footer>
      <p>&copy; 2024 <%= @site[:site_name] %></p>
    </footer>
  </body>
</html>
```

#### Available Variables in Layouts

- `@page` - Current page data (title, date, tags, etc.)
- `@site` - Site configuration from `config/alkali.exs`
- `@content` - Rendered HTML content
- `@collections` - All collections (tags, categories)

### Collections

Collections are automatically generated for tags and categories.

If you have posts with these tags:

```markdown
tags: [elixir, phoenix, web]
```

The following pages are automatically created:

- `/tags/elixir.html` - All posts tagged "elixir"
- `/tags/phoenix.html` - All posts tagged "phoenix"
- `/tags/web.html` - All posts tagged "web"

Same for categories:

```markdown
category: technology
```

Creates:

- `/categories/technology.html` - All posts in "technology" category

### Assets

Place your CSS, JavaScript, and images in the `static/` directory:

```
static/
├── css/
│   └── app.css
├── js/
│   └── app.js
└── images/
    └── logo.png
```

#### CSS & JavaScript

CSS and JS files are automatically:

- **Minified** - Comments removed, whitespace collapsed
- **Fingerprinted** - Cache-busting hashes added
- **Referenced** - HTML updated with fingerprinted URLs

**Input:** `static/css/app.css`

```css
/* Comment */
body {
  margin: 0;
  padding: 0;
}
```

**Output:** `_site/css/app-3e67b4a9.css`

```css
body {
  margin: 0;
  padding: 0;
}
```

**HTML automatically updated:**

```html
<!-- Before -->
<link rel="stylesheet" href="/css/app.css" />

<!-- After -->
<link rel="stylesheet" href="/css/app-3e67b4a9.css" />
```

#### Images & Binary Files

Images and other binary files are copied as-is without modification:

**Input:** `static/images/logo.png`
**Output:** `_site/images/logo.png`

### Build Options

```bash
# Standard build
mix alkali.build

# Include draft posts
mix alkali.build --draft

# Clean output directory before building
mix alkali.build --clean

# Verbose output (show all steps)
mix alkali.build --verbose
```

### Incremental Builds

By default, Alkali only rebuilds changed files:

```bash
# First build - builds everything
mix alkali.build
# => Built 10 files

# Edit one post
vim content/posts/my-post.md

# Second build - only rebuilds changed file
mix alkali.build
# => Rebuilt 1 file (1 changed, 9 skipped)
```

The build cache is stored in `.alkali_cache.json`. Delete this file to force a full rebuild:

```bash
rm .alkali_cache.json
mix alkali.build
```

## Mix Tasks

### `mix alkali.new <name>`

Creates a new static site with starter templates and example content.

```bash
mix alkali.new my_blog
```

Options:

- `--path` - Custom path for the new site (default: current directory)

### `mix alkali.build [path]`

Builds the static site.

```bash
# Build current directory
mix alkali.build

# Build specific path
mix alkali.build ~/my_blog
```

Options:

- `--draft` / `-d` - Include draft posts
- `--verbose` / `-v` - Show detailed build output
- `--clean` / `-c` - Clean output directory before building

### `mix alkali.post <title> [path]`

Creates a new blog post with pre-filled frontmatter.

```bash
mix alkali.post "My Post Title"
```

This creates `content/posts/2024-01-15-my-post-title.md` with:

- Current date
- Title from argument
- Default frontmatter fields

### `mix alkali.clean [path]`

Removes the `_site/` output directory.

```bash
mix alkali.clean
```

## Configuration

Create a `config/alkali.exs` file:

```elixir
import Config

config :alkali,
  site: %{
    title: "My Awesome Blog",
    url: "https://myblog.com",
    author: "Your Name",
    description: "A blog about Elixir and web development"
  }
```

## Deployment

Alkali generates a static `_site/` directory that can be deployed anywhere:

### Netlify

```bash
# Build
mix alkali.build

# Deploy
netlify deploy --prod --dir=_site
```

### Vercel

```bash
# Build
mix alkali.build

# Deploy
vercel --prod _site
```

### GitHub Pages

```bash
# Build
mix alkali.build

# Copy to docs/ (if using docs/ for GitHub Pages)
cp -r _site/* docs/

# Commit and push
git add docs/
git commit -m "Update site"
git push
```

### Any Static Host

Just upload the contents of `_site/` to your web server!

## Examples

### Example Blog Post

```markdown
---
title: Getting Started with Elixir
date: 2024-01-15
tags: [elixir, tutorial, beginners]
category: programming
layout: post
---

# Getting Started with Elixir

Elixir is a functional programming language that runs on the Erlang VM...

## Installation

\`\`\`bash

# macOS

brew install elixir

# Ubuntu

sudo apt-get install elixir
\`\`\`

## Your First Program

\`\`\`elixir
IO.puts "Hello, World!"
\`\`\`
```

### Example Layout

**layouts/post.html.heex:**

```heex
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><%= @page.title %> - <%= @site[:site_name] %></title>
    <link rel="stylesheet" href="/css/app.css">
  </head>
  <body>
    <header>
      <h1><a href="/"><%= @site[:site_name] %></a></h1>
    </header>

    <article>
      <h1><%= @page.title %></h1>

      <div class="meta">
        <%= if @page.date do %>
          <time datetime="<%= @page.date %>">
            <%= Calendar.strftime(@page.date, "%B %d, %Y") %>
          </time>
        <% end %>

        <%= if @page.category do %>
          <span class="category">
            <a href="/categories/<%= @page.category %>.html">
              <%= @page.category %>
            </a>
          </span>
        <% end %>
      </div>

      <div class="content">
        <%= @content %>
      </div>

      <%= if length(@page.tags) > 0 do %>
        <div class="tags">
          Tags:
          <%= for tag <- @page.tags do %>
            <a href="/tags/<%= tag %>.html"><%= tag %></a>
          <% end %>
        </div>
      <% end %>
    </article>

    <footer>
      <p>&copy; <%= DateTime.utc_now().year %> <%= @site[:author] %></p>
    </footer>
  </body>
</html>
```

## Architecture

Alkali follows Clean Architecture principles:

```
Domain Layer (Entities)
  ├── Page - Represents a content page
  ├── Collection - Represents a group of pages
  └── Asset - Represents a static asset file

Application Layer (Use Cases)
  ├── ParseContent - Parses Markdown files
  ├── GenerateCollections - Creates tag/category pages
  ├── ProcessAssets - Minifies and fingerprints assets
  └── BuildSite - Orchestrates the entire build

Infrastructure Layer
  ├── LayoutResolver - Resolves and renders layouts
  ├── BuildCache - Manages incremental build cache
  └── FileSystem - File I/O operations

Interface Layer (Mix Tasks)
  ├── mix alkali.new - Site generator
  ├── mix alkali.build - Build command
  └── mix alkali.post - Post generator
```

## Development

### Running Tests

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/alkali/application/use_cases/build_site_test.exs
```

### Code Quality

```bash
# Format code
mix format

# Run Credo
mix credo

# Run Dialyzer
mix dialyzer
```

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`mix test`)
5. Format your code (`mix format`)
6. Commit your changes (`git commit -am 'Add new feature'`)
7. Push to the branch (`git push origin feature/my-feature`)
8. Create a Pull Request

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Credits

Built with ❤️ using Elixir.

Inspired by:

- Jekyll - Ruby-based static site generator
- Hugo - Go-based static site generator
- Eleventy - JavaScript-based static site generator

## Changelog

### v0.1.0

**Initial Release**

- ✅ Markdown content parsing with YAML frontmatter
- ✅ EEx template rendering with layouts
- ✅ Automatic tag and category collections
- ✅ CSS/JS minification and fingerprinting
- ✅ Incremental builds with file change detection
- ✅ Mix tasks for building and content creation
- ✅ 156/156 tests passing (100% coverage)
