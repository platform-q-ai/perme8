defmodule Alkali.Infrastructure.LayoutResolverTest do
  use ExUnit.Case, async: true

  alias Alkali.Infrastructure.LayoutResolver

  setup do
    # Create temporary directory structure for testing
    test_dir =
      System.tmp_dir!()
      |> Path.join("layout_resolver_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(test_dir)
    layouts_dir = Path.join(test_dir, "layouts")
    File.mkdir_p!(layouts_dir)

    # Create test layout files
    File.write!(Path.join(layouts_dir, "default.html.heex"), "<html><%= @content %></html>")
    File.write!(Path.join(layouts_dir, "post.html.heex"), "<article><%= @content %></article>")

    File.write!(
      Path.join(layouts_dir, "custom.html.heex"),
      "<div class='custom'><%= @content %></div>"
    )

    on_exit(fn -> File.rm_rf!(test_dir) end)

    {:ok, test_dir: test_dir, layouts_dir: layouts_dir}
  end

  describe "resolve_layout/3" do
    test "uses layout from page frontmatter when specified", %{test_dir: test_dir} do
      page = %{
        title: "My Post",
        layout: "custom",
        url: "/posts/my-post"
      }

      config = %{
        site_path: test_dir,
        layouts_path: "layouts"
      }

      assert {:ok, layout_path} = LayoutResolver.resolve_layout(page, config, [])
      assert String.ends_with?(layout_path, "layouts/custom.html.heex")
      assert File.exists?(layout_path)
    end

    test "uses folder-based default layout when frontmatter layout not specified", %{
      test_dir: test_dir
    } do
      page = %{
        title: "My Post",
        layout: nil,
        url: "/posts/2024/my-post"
      }

      config = %{
        site_path: test_dir,
        layouts_path: "layouts"
      }

      assert {:ok, layout_path} = LayoutResolver.resolve_layout(page, config, [])
      assert String.ends_with?(layout_path, "layouts/post.html.heex")
      assert File.exists?(layout_path)
    end

    test "uses site default layout when folder-based layout doesn't exist", %{test_dir: test_dir} do
      page = %{
        title: "About Page",
        layout: nil,
        url: "/about"
      }

      config = %{
        site_path: test_dir,
        layouts_path: "layouts"
      }

      assert {:ok, layout_path} = LayoutResolver.resolve_layout(page, config, [])
      assert String.ends_with?(layout_path, "layouts/default.html.heex")
      assert File.exists?(layout_path)
    end

    test "returns error when specified layout doesn't exist", %{test_dir: test_dir} do
      page = %{
        title: "My Post",
        layout: "nonexistent",
        url: "/posts/my-post"
      }

      config = %{
        site_path: test_dir,
        layouts_path: "layouts"
      }

      assert {:error, message} = LayoutResolver.resolve_layout(page, config, [])
      assert message =~ "Layout 'nonexistent' not found"
      assert message =~ "Looked in:"
    end

    test "returns error when default layout doesn't exist", %{test_dir: test_dir} do
      # Remove default layout
      default_layout = Path.join([test_dir, "layouts", "default.html.heex"])
      File.rm!(default_layout)

      page = %{
        title: "About Page",
        layout: nil,
        url: "/about"
      }

      config = %{
        site_path: test_dir,
        layouts_path: "layouts"
      }

      assert {:error, message} = LayoutResolver.resolve_layout(page, config, [])
      assert message =~ "Layout 'default' not found"
      assert message =~ "Looked in:"
    end
  end

  describe "extract_folder_from_url/1" do
    test "extracts folder from URL with date structure" do
      assert LayoutResolver.extract_folder_from_url("/posts/2024/my-post") == "posts"
    end

    test "extracts folder from URL with single segment" do
      assert LayoutResolver.extract_folder_from_url("/pages/about") == "pages"
    end

    test "returns 'page' for root-level URLs" do
      assert LayoutResolver.extract_folder_from_url("/about") == "page"
    end

    test "returns 'page' for empty URL" do
      assert LayoutResolver.extract_folder_from_url("") == "page"
    end
  end

  describe "render_with_layout/4" do
    test "renders page content with layout", %{test_dir: test_dir} do
      page = %{
        title: "My Post",
        content: "<p>Hello World</p>",
        date: ~D[2024-01-15],
        tags: ["elixir"]
      }

      layout_path = Path.join([test_dir, "layouts", "post.html.heex"])

      config = %{
        site_name: "My Blog",
        site_url: "https://example.com"
      }

      assert {:ok, html} = LayoutResolver.render_with_layout(page, layout_path, config, [])
      assert html =~ "<article>"
      assert html =~ "<p>Hello World</p>"
      assert html =~ "</article>"
    end

    test "passes page and site variables to template", %{test_dir: test_dir} do
      # Create a layout that uses page and site variables
      layout_path = Path.join([test_dir, "layouts", "test.html.heex"])

      File.write!(layout_path, """
      <html>
        <title><%= @page.title %> - <%= @site.site_name %></title>
        <body><%= @content %></body>
      </html>
      """)

      page = %{
        title: "My Post",
        content: "<p>Content</p>"
      }

      config = %{
        site: %{
          site_name: "Test Blog"
        }
      }

      assert {:ok, html} = LayoutResolver.render_with_layout(page, layout_path, config, [])
      assert html =~ "<title>My Post - Test Blog</title>"
      assert html =~ "<p>Content</p>"
    end

    test "returns error when layout file doesn't exist", %{test_dir: test_dir} do
      page = %{
        title: "My Post",
        content: "<p>Hello</p>"
      }

      layout_path = Path.join([test_dir, "layouts", "nonexistent.html.heex"])
      config = %{}

      assert {:error, message} = LayoutResolver.render_with_layout(page, layout_path, config, [])
      assert message =~ "Failed to read layout"
    end

    test "renders partials within layout", %{test_dir: test_dir} do
      # Create a partial
      partials_dir = Path.join([test_dir, "layouts", "partials"])
      File.mkdir_p!(partials_dir)

      partial_path = Path.join(partials_dir, "_header.html.heex")

      File.write!(partial_path, """
      <header>
        <h1>Site Header</h1>
      </header>
      """)

      # Create a layout that uses the partial
      layout_path = Path.join([test_dir, "layouts", "with_partial.html.heex"])

      File.write!(layout_path, """
      <html>
        <%= render_partial("_header.html.heex", assigns) %>
        <main><%= @content %></main>
      </html>
      """)

      page = %{
        title: "My Post",
        content: "<p>Post content</p>"
      }

      config = %{site_name: "Test Blog"}

      assert {:ok, html} = LayoutResolver.render_with_layout(page, layout_path, config, [])
      assert html =~ "<header>"
      assert html =~ "<h1>Site Header</h1>"
      assert html =~ "</header>"
      assert html =~ "<p>Post content</p>"
    end

    test "handles missing partials gracefully", %{test_dir: test_dir} do
      # Create a layout that references a non-existent partial
      layout_path = Path.join([test_dir, "layouts", "missing_partial.html.heex"])

      File.write!(layout_path, """
      <html>
        <%= render_partial("_nonexistent.html.heex", assigns) %>
        <main><%= @content %></main>
      </html>
      """)

      page = %{
        title: "My Post",
        content: "<p>Post content</p>"
      }

      config = %{site_name: "Test Blog"}

      assert {:ok, html} = LayoutResolver.render_with_layout(page, layout_path, config, [])
      # Should render without the partial (empty string replacement)
      assert html =~ "<html>"
      assert html =~ "<p>Post content</p>"
      refute html =~ "nonexistent"
    end
  end
end
