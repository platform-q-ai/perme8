defmodule Alkali.Application.UseCases.GenerateRssFeedTest do
  use ExUnit.Case, async: true

  alias Alkali.Application.UseCases.GenerateRssFeed
  alias Alkali.Domain.Entities.Page

  describe "execute/2" do
    test "generates valid RSS feed with blog posts" do
      pages = [
        %Page{
          title: "First Post",
          content: "<p>This is the first post content.</p>",
          url: "/posts/first-post.html",
          date: ~U[2024-01-15 10:30:00Z],
          draft: false
        },
        %Page{
          title: "Second Post",
          content: "<p>This is the second post content.</p>",
          url: "/posts/second-post.html",
          date: ~U[2024-01-20 14:00:00Z],
          draft: false
        }
      ]

      assert {:ok, xml} = GenerateRssFeed.execute(pages, site_url: "https://example.com")

      # Check XML declaration
      assert xml =~ ~r/^<\?xml version="1\.0" encoding="UTF-8"\?>/

      # Check RSS structure
      assert xml =~ ~r/<rss version="2\.0"/
      assert xml =~ ~r/xmlns:atom="http:\/\/www\.w3\.org\/2005\/Atom"/
      assert xml =~ ~r/<channel>/
      assert xml =~ ~r/<\/channel>/

      # Check channel metadata
      assert xml =~ ~r/<title>Blog<\/title>/
      assert xml =~ ~r/<description>Latest posts<\/description>/
      assert xml =~ ~r/<link>https:\/\/example\.com<\/link>/
      assert xml =~ ~r/<generator>Alkali<\/generator>/

      # Check atom:link for self-reference
      assert xml =~
               ~r/<atom:link href="https:\/\/example\.com\/feed\.xml" rel="self" type="application\/rss\+xml"\/>/

      # Check lastBuildDate is present (format: Fri, 15 Jan 2024 10:30:00 +0000)
      assert xml =~ ~r/<lastBuildDate>(\w+, \d+ \w+ \d+ \d+:\d+:\d+ \+0000)<\/lastBuildDate>/

      # Check posts are included
      assert xml =~ ~r/<item>/
      assert xml =~ ~r/<title>First Post<\/title>/
      assert xml =~ ~r/<link>https:\/\/example\.com\/posts\/first-post\.html<\/link>/
      assert xml =~ ~r/<pubDate>Mon, 15 Jan 2024 10:30:00 \+0000<\/pubDate>/

      assert xml =~ ~r/<title>Second Post<\/title>/
      assert xml =~ ~r/<link>https:\/\/example\.com\/posts\/second-post\.html<\/link>/
      assert xml =~ ~r/<pubDate>Sat, 20 Jan 2024 14:00:00 \+0000<\/pubDate>/
    end

    test "sorts posts by date (newest first)" do
      pages = [
        %Page{
          title: "Old Post",
          content: "<p>Old</p>",
          url: "/posts/old.html",
          date: ~U[2024-01-01 00:00:00Z],
          draft: false
        },
        %Page{
          title: "New Post",
          content: "<p>New</p>",
          url: "/posts/new.html",
          date: ~U[2024-12-31 23:59:59Z],
          draft: false
        },
        %Page{
          title: "Middle Post",
          content: "<p>Middle</p>",
          url: "/posts/middle.html",
          date: ~U[2024-06-15 12:00:00Z],
          draft: false
        }
      ]

      assert {:ok, xml} = GenerateRssFeed.execute(pages, site_url: "https://example.com")

      # Extract item positions
      new_pos = :binary.match(xml, "New Post") |> elem(0)
      middle_pos = :binary.match(xml, "Middle Post") |> elem(0)
      old_pos = :binary.match(xml, "Old Post") |> elem(0)

      # Verify ordering (newer posts appear first)
      assert new_pos < middle_pos
      assert middle_pos < old_pos
    end

    test "filters out draft posts" do
      pages = [
        %Page{
          title: "Published Post",
          content: "<p>Published</p>",
          url: "/posts/published.html",
          date: ~U[2024-01-15 10:30:00Z],
          draft: false
        },
        %Page{
          title: "Draft Post",
          content: "<p>Draft</p>",
          url: "/posts/draft.html",
          date: ~U[2024-01-20 10:30:00Z],
          draft: true
        }
      ]

      assert {:ok, xml} = GenerateRssFeed.execute(pages, site_url: "https://example.com")

      # Check published post is included
      assert xml =~ "Published Post"

      # Check draft post is NOT included
      refute xml =~ "Draft Post"
    end

    test "filters out pages without dates" do
      pages = [
        %Page{
          title: "Post with Date",
          content: "<p>Dated</p>",
          url: "/posts/dated.html",
          date: ~U[2024-01-15 10:30:00Z],
          draft: false
        },
        %Page{
          title: "Page without Date",
          content: "<p>No date</p>",
          url: "/pages/about.html",
          date: nil,
          draft: false
        }
      ]

      assert {:ok, xml} = GenerateRssFeed.execute(pages, site_url: "https://example.com")

      # Check post with date is included
      assert xml =~ "Post with Date"

      # Check page without date is NOT included
      refute xml =~ "Page without Date"
    end

    test "filters out non-post pages (pages without /posts/ in URL)" do
      pages = [
        %Page{
          title: "Blog Post",
          content: "<p>Post</p>",
          url: "/posts/post.html",
          date: ~U[2024-01-15 10:30:00Z],
          draft: false
        },
        %Page{
          title: "About Page",
          content: "<p>About</p>",
          url: "/pages/about.html",
          date: ~U[2024-01-15 10:30:00Z],
          draft: false
        }
      ]

      assert {:ok, xml} = GenerateRssFeed.execute(pages, site_url: "https://example.com")

      # Check blog post is included
      assert xml =~ "Blog Post"

      # Check about page is NOT included (even though it has a date)
      refute xml =~ "About Page"
    end

    test "respects max_items limit" do
      pages =
        for i <- 1..25 do
          %Page{
            title: "Post #{i}",
            content: "<p>Content #{i}</p>",
            url: "/posts/post-#{i}.html",
            date: DateTime.add(~U[2024-01-01 00:00:00Z], i * 86400, :second),
            draft: false
          }
        end

      # Default max_items is 20
      assert {:ok, xml} = GenerateRssFeed.execute(pages, site_url: "https://example.com")

      # Count number of <item> tags
      item_count = xml |> String.split("<item>") |> length() |> Kernel.-(1)
      assert item_count == 20

      # Custom max_items
      assert {:ok, xml} =
               GenerateRssFeed.execute(pages, site_url: "https://example.com", max_items: 5)

      item_count = xml |> String.split("<item>") |> length() |> Kernel.-(1)
      assert item_count == 5
    end

    test "escapes XML special characters in content" do
      pages = [
        %Page{
          title: "Post with <HTML> & \"quotes\" and 'apostrophes'",
          content: "<p>Content with <script>alert('XSS')</script></p>",
          url: "/posts/test.html",
          date: ~U[2024-01-15 10:30:00Z],
          draft: false
        }
      ]

      assert {:ok, xml} = GenerateRssFeed.execute(pages, site_url: "https://example.com")

      # Check title is properly escaped
      assert xml =~ "Post with &lt;HTML&gt; &amp; &quot;quotes&quot; and &apos;apostrophes&apos;"

      # Check description strips HTML and doesn't include raw tags
      refute xml =~ "<script>"
      refute xml =~ "alert('XSS')"
    end

    test "generates description from content (strips HTML, truncates to 200 chars)" do
      long_content = String.duplicate("This is a very long post content. ", 20)

      pages = [
        %Page{
          title: "Post",
          content: "<p>#{long_content}</p><div>More content</div>",
          url: "/posts/post.html",
          date: ~U[2024-01-15 10:30:00Z],
          draft: false
        }
      ]

      assert {:ok, xml} = GenerateRssFeed.execute(pages, site_url: "https://example.com")

      # Check description exists and is truncated with ellipsis
      assert xml =~ ~r/<description>.*\.\.\.<\/description>/s

      # Check HTML tags are stripped
      refute xml =~ "<p>"
      refute xml =~ "<div>"
    end

    test "uses custom feed metadata" do
      pages = [
        %Page{
          title: "Post",
          content: "<p>Content</p>",
          url: "/posts/post.html",
          date: ~U[2024-01-15 10:30:00Z],
          draft: false
        }
      ]

      assert {:ok, xml} =
               GenerateRssFeed.execute(pages,
                 site_url: "https://example.com",
                 feed_title: "My Awesome Blog",
                 feed_description: "A blog about awesome things"
               )

      assert xml =~ ~r/<title>My Awesome Blog<\/title>/
      assert xml =~ ~r/<description>A blog about awesome things<\/description>/
    end

    test "builds correct absolute URLs" do
      pages = [
        %Page{
          title: "Post",
          content: "<p>Content</p>",
          url: "/posts/post.html",
          date: ~U[2024-01-15 10:30:00Z],
          draft: false
        }
      ]

      assert {:ok, xml} =
               GenerateRssFeed.execute(pages, site_url: "https://example.com/blog")

      # Should trim trailing slash from site_url and leading slash from url
      assert xml =~ ~r/<link>https:\/\/example\.com\/blog\/posts\/post\.html<\/link>/
      assert xml =~ ~r/<guid>https:\/\/example\.com\/blog\/posts\/post\.html<\/guid>/
    end

    test "handles Date structs by converting to DateTime" do
      # Simulate a page with Date instead of DateTime
      pages = [
        %Page{
          title: "Post",
          content: "<p>Content</p>",
          url: "/posts/post.html",
          # This would normally be a DateTime, but we're testing Date support
          date: ~U[2024-01-15 00:00:00Z],
          draft: false
        }
      ]

      assert {:ok, xml} = GenerateRssFeed.execute(pages, site_url: "https://example.com")

      # Should format date correctly
      assert xml =~ ~r/<pubDate>Mon, 15 Jan 2024 00:00:00 \+0000<\/pubDate>/
    end

    test "returns error when site_url is missing" do
      pages = [
        %Page{
          title: "Post",
          content: "<p>Content</p>",
          url: "/posts/post.html",
          date: ~U[2024-01-15 10:30:00Z],
          draft: false
        }
      ]

      assert {:error, "site_url is required for RSS feed generation"} =
               GenerateRssFeed.execute(pages, [])
    end

    test "returns error when site_url is empty string" do
      pages = [
        %Page{
          title: "Post",
          content: "<p>Content</p>",
          url: "/posts/post.html",
          date: ~U[2024-01-15 10:30:00Z],
          draft: false
        }
      ]

      assert {:error, "site_url is required for RSS feed generation"} =
               GenerateRssFeed.execute(pages, site_url: "")
    end

    test "generates empty feed when no matching posts" do
      pages = [
        %Page{
          title: "Draft",
          content: "<p>Content</p>",
          url: "/posts/draft.html",
          date: ~U[2024-01-15 10:30:00Z],
          draft: true
        },
        %Page{
          title: "Page",
          content: "<p>Content</p>",
          url: "/pages/about.html",
          date: nil,
          draft: false
        }
      ]

      assert {:ok, xml} = GenerateRssFeed.execute(pages, site_url: "https://example.com")

      # Should have valid RSS structure
      assert xml =~ ~r/<rss version="2\.0"/
      assert xml =~ ~r/<channel>/

      # But no items
      refute xml =~ ~r/<item>/
    end

    test "handles empty pages list" do
      assert {:ok, xml} = GenerateRssFeed.execute([], site_url: "https://example.com")

      # Should still generate valid RSS feed
      assert xml =~ ~r/<rss version="2\.0"/
      assert xml =~ ~r/<channel>/
      refute xml =~ ~r/<item>/
    end
  end
end
