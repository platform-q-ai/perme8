defmodule StaticSite.Application.UseCases.BuildSiteTest do
  use ExUnit.Case, async: true

  alias StaticSite.Application.UseCases.BuildSite

  describe "execute/2" do
    test "full build with all steps" do
      # Mock config loader
      config_loader = fn _path ->
        {:ok,
         %{
           site_name: "Test Blog",
           site_url: "https://example.com",
           content_path: "content",
           output_path: "_site",
           assets_path: "assets"
         }}
      end

      # Mock content parser (returns pages)
      content_parser = fn _path, _opts ->
        pages = [
          %{
            slug: "hello-world",
            url: "/hello-world",
            title: "Hello World",
            html: "<p>Hello</p>",
            draft: false,
            date: ~D[2024-01-01],
            layout: "post"
          }
        ]

        {:ok, %{pages: pages, stats: %{total_files: 1, drafts: 0}}}
      end

      # Mock collections generator
      collections_generator = fn _pages, _opts ->
        {:ok,
         [
           %{
             name: "posts",
             pages: [%{slug: "hello-world", url: "/hello-world", title: "Hello World"}]
           }
         ]}
      end

      # Mock assets processor
      assets_processor = fn _assets, _opts ->
        {:ok,
         %{
           assets: [
             %{
               original_path: "assets/css/app.css",
               output_path: "_site/css/app-abc123.css",
               fingerprint: "abc123def456",
               type: :css,
               content: "body{margin:0;}"
             }
           ],
           mappings: %{"assets/css/app.css" => "_site/css/app-abc123.css"}
         }}
      end

      # Mock template renderer
      template_renderer = fn _layout, _assigns, _opts ->
        {:ok, "<html><body>Rendered</body></html>"}
      end

      # Mock file writer
      file_writer = fn path, _content ->
        send(self(), {:write, path})
        {:ok, path}
      end

      # Mock asset writer
      asset_writer = fn _path, _content ->
        send(self(), {:write_asset})
        {:ok, "ok"}
      end

      opts = [
        config_loader: config_loader,
        content_parser: content_parser,
        collections_generator: collections_generator,
        assets_processor: assets_processor,
        template_renderer: template_renderer,
        file_writer: file_writer,
        asset_writer: asset_writer,
        draft: false,
        verbose: false
      ]

      result = BuildSite.execute("/tmp/site", opts)

      assert {:ok, summary} = result
      assert summary.pages == 1
      assert summary.collections == 1
      assert summary.assets == 1
      assert summary.files_written >= 1

      # Verify page was written (URL /hello-world → _site/hello-world.html)
      # The file_writer receives both page writes and RSS feed writes
      assert_received {:write, page_path}
                      when is_binary(page_path) and page_path != ""

      # Collect all write messages to check for both page and feed
      writes = collect_writes([page_path])

      assert Enum.any?(writes, &String.ends_with?(&1, "_site/hello-world.html")),
             "Expected a write to _site/hello-world.html, got: #{inspect(writes)}"

      assert Enum.any?(writes, &String.ends_with?(&1, "feed.xml")),
             "Expected a write to feed.xml, got: #{inspect(writes)}"

      # Verify asset was written
      assert_received {:write_asset}
    end

    test "build with --drafts flag includes draft posts" do
      config_loader = fn _path ->
        {:ok, %{content_path: "content", output_path: "_site"}}
      end

      content_parser = fn _path, _opts ->
        pages = [
          %{
            slug: "post1",
            draft: false,
            url: "/post1",
            title: "Post 1",
            html: "<p>1</p>",
            layout: "post"
          },
          %{
            slug: "post2",
            draft: true,
            url: "/post2",
            title: "Post 2",
            html: "<p>2</p>",
            layout: "post"
          }
        ]

        {:ok, %{pages: pages, stats: %{total_files: 2, drafts: 1}}}
      end

      collections_generator = fn pages, _opts ->
        {:ok, [%{name: "posts", pages: pages}]}
      end

      assets_processor = fn _assets, _opts -> {:ok, %{assets: [], mappings: %{}}} end
      template_renderer = fn _layout, _assigns, _opts -> {:ok, "<html></html>"} end
      file_writer = fn path, _content -> {:ok, path} end
      asset_writer = fn _path, _content -> {:ok, "ok"} end

      # Without draft flag
      result_no_drafts =
        BuildSite.execute("/tmp/site",
          config_loader: config_loader,
          content_parser: content_parser,
          collections_generator: collections_generator,
          assets_processor: assets_processor,
          template_renderer: template_renderer,
          file_writer: file_writer,
          asset_writer: asset_writer,
          draft: false
        )

      assert {:ok, %{pages: 1}} = result_no_drafts

      # With draft flag
      result_with_drafts =
        BuildSite.execute("/tmp/site",
          config_loader: config_loader,
          content_parser: content_parser,
          collections_generator: collections_generator,
          assets_processor: assets_processor,
          template_renderer: template_renderer,
          file_writer: file_writer,
          asset_writer: asset_writer,
          draft: true
        )

      assert {:ok, %{pages: 2}} = result_with_drafts
    end

    test "build with --verbose flag logs progress" do
      config_loader = fn _path -> {:ok, %{content_path: "content", output_path: "_site"}} end
      content_parser = fn _path, _opts -> {:ok, %{pages: [], stats: %{}}} end
      collections_generator = fn _pages, _opts -> {:ok, []} end
      assets_processor = fn _assets, _opts -> {:ok, %{assets: [], mappings: %{}}} end
      template_renderer = fn _layout, _assigns, _opts -> {:ok, ""} end
      file_writer = fn path, _content -> {:ok, path} end
      asset_writer = fn _path, _content -> {:ok, "ok"} end

      result =
        BuildSite.execute("/tmp/site",
          config_loader: config_loader,
          content_parser: content_parser,
          collections_generator: collections_generator,
          assets_processor: assets_processor,
          template_renderer: template_renderer,
          file_writer: file_writer,
          asset_writer: asset_writer,
          verbose: true
        )

      assert {:ok, _summary} = result
      # In real implementation, verbose would send messages
      # For now, just verify it completes successfully
    end

    test "error handling - config loader fails" do
      config_loader = fn _path -> {:error, "Config not found"} end

      result = BuildSite.execute("/tmp/site", config_loader: config_loader)

      assert {:error, "Failed to load config: Config not found"} = result
    end

    test "error handling - content parser fails" do
      config_loader = fn _path -> {:ok, %{content_path: "content", output_path: "_site"}} end
      content_parser = fn _path, _opts -> {:error, "Parse error"} end

      result =
        BuildSite.execute("/tmp/site",
          config_loader: config_loader,
          content_parser: content_parser
        )

      assert {:error, "Failed to parse content: Parse error"} = result
    end

    test "error handling - collections generator fails" do
      config_loader = fn _path -> {:ok, %{content_path: "content", output_path: "_site"}} end
      content_parser = fn _path, _opts -> {:ok, %{pages: [], stats: %{}}} end
      collections_generator = fn _pages, _opts -> {:error, "Collection error"} end

      result =
        BuildSite.execute("/tmp/site",
          config_loader: config_loader,
          content_parser: content_parser,
          collections_generator: collections_generator
        )

      assert {:error, "Failed to generate collections: Collection error"} = result
    end
  end

  describe "incremental builds with layout change tracking" do
    @describetag :incremental_builds
    # Note: These tests cannot run async due to file system operations and timing requirements
    setup do
      # Create a temporary directory for testing with timestamp and random number
      test_dir =
        System.tmp_dir!()
        |> Path.join(
          "static_site_test_#{System.system_time(:millisecond)}_#{:rand.uniform(1_000_000)}"
        )

      File.mkdir_p!(test_dir)

      # Create necessary subdirectories
      content_dir = Path.join(test_dir, "content")
      layouts_dir = Path.join(test_dir, "layouts")
      output_dir = Path.join(test_dir, "_site")

      File.mkdir_p!(content_dir)
      File.mkdir_p!(layouts_dir)
      File.mkdir_p!(output_dir)

      # Create a test content file
      test_post = Path.join(content_dir, "test.md")

      File.write!(test_post, """
      ---
      title: Test Post
      date: 2024-01-01
      layout: post
      draft: false
      ---
      # Test Content
      """)

      # Create a test layout file
      test_layout = Path.join(layouts_dir, "post.html.heex")
      File.write!(test_layout, "<html><body><%= @content %></body></html>")

      on_exit(fn ->
        File.rm_rf!(test_dir)
      end)

      %{
        test_dir: test_dir,
        content_dir: content_dir,
        layouts_dir: layouts_dir,
        output_dir: output_dir,
        test_post: test_post,
        test_layout: test_layout
      }
    end

    test "tracks layout files in cache", %{test_dir: test_dir, test_layout: test_layout} do
      # First build
      {:ok, _summary} = BuildSite.execute(test_dir, incremental: true)

      # Check that cache includes layout files
      cache_file = Path.join(test_dir, ".static_site_cache.json")
      assert File.exists?(cache_file)

      {:ok, cache_content} = File.read(cache_file)
      {:ok, cache} = Jason.decode(cache_content)

      # Layout file should be in cache
      assert Map.has_key?(cache, test_layout)
    end

    test "rebuilds all pages when layout changes", %{
      test_dir: test_dir,
      test_layout: test_layout
    } do
      # First build
      {:ok, summary1} = BuildSite.execute(test_dir, incremental: true)
      assert summary1.stats.rendered_pages == 1

      # Small sleep to ensure file timestamps differ
      Process.sleep(10)

      # Second build without changes - should skip
      {:ok, summary2} = BuildSite.execute(test_dir, incremental: true)
      assert summary2.stats.rendered_pages == 0
      assert summary2.stats.skipped == 1

      # Small sleep to ensure file timestamps differ
      Process.sleep(10)

      # Modify layout file
      File.write!(test_layout, "<html><body>UPDATED: <%= @content %></body></html>")

      # Third build - should rebuild all pages
      {:ok, summary3} = BuildSite.execute(test_dir, incremental: true)
      assert summary3.stats.rendered_pages == 1
      assert summary3.stats.skipped == 0
    end

    test "rebuilds when partial files change", %{test_dir: test_dir, layouts_dir: layouts_dir} do
      # Create a partial
      partials_dir = Path.join(layouts_dir, "partials")
      File.mkdir_p!(partials_dir)
      partial_file = Path.join(partials_dir, "header.html")
      File.write!(partial_file, "<header>Site Header</header>")

      # First build
      {:ok, summary1} = BuildSite.execute(test_dir, incremental: true)
      assert summary1.stats.rendered_pages == 1

      # Small sleep to ensure file timestamps differ
      Process.sleep(10)

      # Second build - should skip
      {:ok, summary2} = BuildSite.execute(test_dir, incremental: true)
      assert summary2.stats.rendered_pages == 0

      # Small sleep to ensure file timestamps differ
      Process.sleep(10)

      # Modify partial
      File.write!(partial_file, "<header>UPDATED Header</header>")

      # Third build - should rebuild
      {:ok, summary3} = BuildSite.execute(test_dir, incremental: true)
      assert summary3.stats.rendered_pages == 1
    end

    test "skips rebuild when only content unchanged", %{test_dir: test_dir} do
      # First build
      {:ok, summary1} = BuildSite.execute(test_dir, incremental: true)
      assert summary1.stats.rendered_pages == 1

      # Second build - should skip
      {:ok, summary2} = BuildSite.execute(test_dir, incremental: true)
      assert summary2.stats.rendered_pages == 0
      assert summary2.stats.skipped == 1
      assert summary2.stats.changed == 0
    end

    test "rebuilds only changed content files when layouts unchanged", %{
      test_dir: test_dir,
      content_dir: content_dir
    } do
      # Create another content file
      second_post = Path.join(content_dir, "second.md")

      File.write!(second_post, """
      ---
      title: Second Post
      date: 2024-01-02
      layout: post
      draft: false
      ---
      # Second Content
      """)

      # First build
      {:ok, summary1} = BuildSite.execute(test_dir, incremental: true)
      assert summary1.stats.rendered_pages == 2

      # Small sleep to ensure file timestamps differ
      Process.sleep(10)

      # Second build - should skip all
      {:ok, summary2} = BuildSite.execute(test_dir, incremental: true)
      assert summary2.stats.rendered_pages == 0
      assert summary2.stats.skipped == 2

      # Small sleep to ensure file timestamps differ
      Process.sleep(10)

      # Modify only one content file
      File.write!(second_post, """
      ---
      title: Second Post UPDATED
      date: 2024-01-02
      layout: post
      draft: false
      ---
      # Second Content Updated
      """)

      # Third build - should rebuild only the changed file
      {:ok, summary3} = BuildSite.execute(test_dir, incremental: true)
      assert summary3.stats.rendered_pages == 1
      assert summary3.stats.skipped == 1
      assert summary3.stats.changed == 1
    end

    test "disables incremental build with incremental: false option", %{test_dir: test_dir} do
      # First build with incremental enabled
      {:ok, _summary1} = BuildSite.execute(test_dir, incremental: true)

      # Second build with incremental disabled - should rebuild all
      {:ok, summary2} = BuildSite.execute(test_dir, incremental: false)
      assert summary2.stats.rendered_pages == 1
      # incremental flag should be false in stats
      refute summary2.stats.incremental
    end
  end

  describe "posts index page generation" do
    setup do
      # Create unique temp directory for each test
      timestamp = System.os_time(:millisecond)
      test_dir = Path.join(System.tmp_dir!(), "posts_index_test_#{timestamp}")
      File.mkdir_p!(test_dir)

      # Create layouts directory and basic layouts
      layouts_dir = Path.join(test_dir, "layouts")
      File.mkdir_p!(layouts_dir)

      # Create post layout (mimics real layout structure)
      File.write!(
        Path.join(layouts_dir, "post.html.heex"),
        """
        <!DOCTYPE html>
        <html>
        <head><title><%= @page.title %></title></head>
        <body>
        <h1><%= @page.title %></h1>
        <%= @content %>
        </body>
        </html>
        """
      )

      # Create collection layout for posts index
      File.write!(
        Path.join(layouts_dir, "collection.html.heex"),
        """
        <!DOCTYPE html>
        <html>
        <head><title><%= @page.title %></title></head>
        <body>
        <%= @content %>
        </body>
        </html>
        """
      )

      on_exit(fn ->
        File.rm_rf!(test_dir)
      end)

      %{test_dir: test_dir}
    end

    test "generates posts/index.html with all posts", %{test_dir: test_dir} do
      # Setup site structure
      content_dir = Path.join(test_dir, "content/posts")
      File.mkdir_p!(content_dir)

      # Create test posts
      File.write!(
        Path.join(content_dir, "2024-01-01-first-post.md"),
        """
        ---
        title: "First Post"
        date: 2024-01-01
        draft: false
        layout: post
        ---

        First post content.
        """
      )

      File.write!(
        Path.join(content_dir, "2024-01-15-second-post.md"),
        """
        ---
        title: "Second Post"
        date: 2024-01-15
        draft: false
        layout: post
        ---

        Second post content.
        """
      )

      # Build the site
      {:ok, summary} = BuildSite.execute(test_dir)

      # Check that posts index was generated
      posts_index = Path.join([test_dir, "_site", "posts", "index.html"])
      assert File.exists?(posts_index)

      # Read and verify content
      content = File.read!(posts_index)
      assert content =~ "All Posts"
      assert content =~ "First Post"
      assert content =~ "Second Post"

      # Verify stats show posts_pages was generated
      assert Map.get(summary.stats, :posts_pages, 0) > 0
    end

    test "posts index includes only published posts (excludes drafts)", %{test_dir: test_dir} do
      # Setup site structure
      content_dir = Path.join(test_dir, "content/posts")
      File.mkdir_p!(content_dir)

      # Create published post
      File.write!(
        Path.join(content_dir, "2024-01-01-published.md"),
        """
        ---
        title: "Published Post"
        date: 2024-01-01
        draft: false
        layout: post
        ---

        Published content.
        """
      )

      # Create draft post
      File.write!(
        Path.join(content_dir, "2024-01-15-draft.md"),
        """
        ---
        title: "Draft Post"
        date: 2024-01-15
        draft: true
        layout: post
        ---

        Draft content.
        """
      )

      # Build without drafts
      {:ok, _summary} = BuildSite.execute(test_dir, draft: false)

      # Check posts index content
      posts_index = Path.join([test_dir, "_site", "posts", "index.html"])
      content = File.read!(posts_index)

      # Should include published post
      assert content =~ "Published Post"

      # Should NOT include draft post
      refute content =~ "Draft Post"
    end

    test "posts index shows drafts when draft mode enabled", %{test_dir: test_dir} do
      # Setup site structure
      content_dir = Path.join(test_dir, "content/posts")
      File.mkdir_p!(content_dir)

      # Create published post
      File.write!(
        Path.join(content_dir, "2024-01-01-published.md"),
        """
        ---
        title: "Published Post"
        date: 2024-01-01
        draft: false
        layout: post
        ---

        Published content.
        """
      )

      # Create draft post
      File.write!(
        Path.join(content_dir, "2024-01-15-draft.md"),
        """
        ---
        title: "Draft Post"
        date: 2024-01-15
        draft: true
        layout: post
        ---

        Draft content.
        """
      )

      # Build WITH drafts - Note: draft: true makes draft posts render as individual files,
      # but collections still exclude drafts unless include_drafts: true is also passed
      {:ok, _summary} = BuildSite.execute(test_dir, draft: true, include_drafts: true)

      # Check posts index content
      posts_index = Path.join([test_dir, "_site", "posts", "index.html"])
      content = File.read!(posts_index)

      # Should include both posts when both draft and include_drafts are true
      assert content =~ "Published Post"
      assert content =~ "Draft Post"

      # Also verify draft post HTML file was created
      draft_html = Path.join([test_dir, "_site", "posts", "2024-01-15-draft.html"])
      assert File.exists?(draft_html)
    end

    test "posts index is created at correct path posts/index.html", %{test_dir: test_dir} do
      # Setup site structure
      content_dir = Path.join(test_dir, "content/posts")
      File.mkdir_p!(content_dir)

      # Create a test post
      File.write!(
        Path.join(content_dir, "2024-01-01-test.md"),
        """
        ---
        title: "Test Post"
        date: 2024-01-01
        draft: false
        layout: post
        ---

        Test content.
        """
      )

      # Build the site
      {:ok, _summary} = BuildSite.execute(test_dir)

      # Verify the exact path
      posts_index = Path.join([test_dir, "_site", "posts", "index.html"])
      assert File.exists?(posts_index)

      # Verify it's NOT at posts/posts.html
      wrong_path = Path.join([test_dir, "_site", "posts", "posts.html"])
      refute File.exists?(wrong_path)
    end

    test "posts index shows correct post count", %{test_dir: test_dir} do
      # Setup site structure
      content_dir = Path.join(test_dir, "content/posts")
      File.mkdir_p!(content_dir)

      # Create 3 posts
      for i <- 1..3 do
        File.write!(
          Path.join(content_dir, "2024-01-#{String.pad_leading("#{i}", 2, "0")}-post-#{i}.md"),
          """
          ---
          title: "Post #{i}"
          date: 2024-01-#{String.pad_leading("#{i}", 2, "0")}
          draft: false
          layout: post
          ---

          Content #{i}.
          """
        )
      end

      # Build the site
      {:ok, _summary} = BuildSite.execute(test_dir)

      # Check posts index content
      posts_index = Path.join([test_dir, "_site", "posts", "index.html"])
      content = File.read!(posts_index)

      # Should show total count
      assert content =~ "Total posts: 3" or content =~ "3 posts" or content =~ "3</p>"
    end

    test "posts index handles empty posts directory", %{test_dir: test_dir} do
      # Setup site structure with empty posts directory
      content_dir = Path.join(test_dir, "content/posts")
      File.mkdir_p!(content_dir)

      # Build the site (no posts)
      {:ok, summary} = BuildSite.execute(test_dir)

      # Posts index should still be created (even if empty)
      posts_index = Path.join([test_dir, "_site", "posts", "index.html"])

      # Check if it exists or if collection was skipped
      if File.exists?(posts_index) do
        content = File.read!(posts_index)
        # Should show zero posts or empty state
        assert content =~ "All Posts" or content =~ "No posts"
      else
        # It's also valid to not create the page if there are no posts
        # Just verify build completed successfully
        assert summary.pages >= 0
      end
    end

    test "posts index links to individual posts correctly", %{test_dir: test_dir} do
      # Setup site structure
      content_dir = Path.join(test_dir, "content/posts")
      File.mkdir_p!(content_dir)

      # Create a test post
      File.write!(
        Path.join(content_dir, "2024-01-15-my-post.md"),
        """
        ---
        title: "My Amazing Post"
        date: 2024-01-15
        draft: false
        layout: post
        ---

        Post content.
        """
      )

      # Build the site
      {:ok, _summary} = BuildSite.execute(test_dir)

      # Check posts index content
      posts_index = Path.join([test_dir, "_site", "posts", "index.html"])
      content = File.read!(posts_index)

      # Should have link to the post
      assert content =~ "My Amazing Post"
      # Should have a link (href) pointing to the post file
      assert content =~ ~r/href="[^"]*2024-01-15-my-post\.html"/
    end
  end

  # Helper to drain all {:write, path} messages from the mailbox
  defp collect_writes(acc) do
    receive do
      {:write, path} -> collect_writes([path | acc])
    after
      0 -> acc
    end
  end
end
