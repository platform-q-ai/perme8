defmodule StaticSite.Domain.Entities.PageTest do
  use ExUnit.Case, async: true

  alias StaticSite.Domain.Entities.Page

  describe "new/1" do
    test "creates a page struct with all fields" do
      attrs = %{
        title: "My First Post",
        content: "<p>Hello world</p>",
        slug: "my-first-post",
        url: "/posts/my-first-post.html",
        date: ~U[2024-01-15 10:30:00Z],
        tags: ["elixir", "blog"],
        category: "tutorials",
        draft: false,
        layout: "post",
        frontmatter: %{
          "title" => "My First Post",
          "author" => "John Doe"
        }
      }

      page = Page.new(attrs)

      assert page.title == "My First Post"
      assert page.content == "<p>Hello world</p>"
      assert page.slug == "my-first-post"
      assert page.url == "/posts/my-first-post.html"
      assert page.date == ~U[2024-01-15 10:30:00Z]
      assert page.tags == ["elixir", "blog"]
      assert page.category == "tutorials"
      assert page.draft == false
      assert page.layout == "post"
      assert page.frontmatter == %{"title" => "My First Post", "author" => "John Doe"}
    end

    test "creates page with minimal fields" do
      attrs = %{
        title: "Simple Page",
        content: "<p>Content</p>",
        slug: "simple-page",
        url: "/simple-page.html"
      }

      page = Page.new(attrs)

      assert page.title == "Simple Page"
      assert page.content == "<p>Content</p>"
      assert page.slug == "simple-page"
      assert page.url == "/simple-page.html"
      assert page.date == nil
      assert page.tags == []
      assert page.category == nil
      assert page.draft == false
      assert page.layout == nil
      assert page.frontmatter == %{}
    end
  end

  describe "from_frontmatter/2" do
    test "converts frontmatter map to Page struct" do
      frontmatter = %{
        "title" => "Blog Post",
        "date" => "2024-01-15T10:30:00Z",
        "tags" => ["elixir"],
        "category" => "tutorials",
        "draft" => false,
        "layout" => "post"
      }

      content = "<p>Rendered content</p>"

      page = Page.from_frontmatter(frontmatter, content)

      assert page.title == "Blog Post"
      assert page.content == "<p>Rendered content</p>"
      assert page.date == ~U[2024-01-15 10:30:00Z]
      assert page.tags == ["elixir"]
      assert page.category == "tutorials"
      assert page.draft == false
      assert page.layout == "post"
    end

    test "handles missing optional fields" do
      frontmatter = %{"title" => "Minimal Post"}
      content = "<p>Content</p>"

      page = Page.from_frontmatter(frontmatter, content)

      assert page.title == "Minimal Post"
      assert page.content == "<p>Content</p>"
      assert page.date == nil
      assert page.tags == []
      assert page.category == nil
      assert page.draft == false
      assert page.layout == nil
    end

    test "parses ISO 8601 date string to DateTime" do
      frontmatter = %{
        "title" => "Post",
        "date" => "2024-01-15T10:30:00Z"
      }

      content = "<p>Content</p>"

      page = Page.from_frontmatter(frontmatter, content)

      assert page.date == ~U[2024-01-15 10:30:00Z]
    end

    test "defaults draft to false when not specified" do
      frontmatter = %{"title" => "Post"}
      content = "<p>Content</p>"

      page = Page.from_frontmatter(frontmatter, content)

      assert page.draft == false
    end

    test "respects draft: true in frontmatter" do
      frontmatter = %{
        "title" => "Draft Post",
        "draft" => true
      }

      content = "<p>Content</p>"

      page = Page.from_frontmatter(frontmatter, content)

      assert page.draft == true
    end
  end
end
