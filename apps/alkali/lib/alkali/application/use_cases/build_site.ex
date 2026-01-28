defmodule Alkali.Application.UseCases.BuildSite do
  @moduledoc """
  BuildSite use case orchestrates the full static site build process.
  """

  @doc """
  Orchestrates the complete build process for a static site.

  ## Steps

  1. Load site configuration
  2. Parse content files
  3. Generate collections
  4. Process assets
  5. Render pages
  6. Write output files

  ## Options

  - `:config_loader` - Function to load site configuration
  - `:content_parser` - Function to parse content files
  - `:collections_generator` - Function to generate collections
  - `:assets_processor` - Function to process assets
  - `:template_renderer` - Function to render templates
  - `:file_writer` - Function to write HTML files
  - `:asset_writer` - Function to write asset files
  - `:draft` - Include draft posts (default: false)
  - `:verbose` - Print progress messages (default: false)

  ## Returns

  - `{:ok, map()}` with build summary on success
  - `{:error, String.t()}` on failure
  """
  @spec execute(String.t(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def execute(site_path, opts \\ []) do
    config_loader = Keyword.get(opts, :config_loader, &default_config_loader/1)
    draft = Keyword.get(opts, :draft, false)
    verbose = Keyword.get(opts, :verbose, false)
    incremental = Keyword.get(opts, :incremental, true)

    # Step 0: Load build cache for incremental builds
    cache =
      if incremental do
        if verbose, do: IO.puts("Loading build cache...")
        Alkali.Infrastructure.BuildCache.load(site_path)
      else
        %{}
      end

    # Step 1: Load config
    config = load_config(site_path, config_loader, verbose)
    # Ensure site_path is always set in config (config_loader may omit it)
    config = Map.put_new(config, :site_path, site_path)

    # Step 2: Parse content
    content_result = parse_content(config, opts, verbose)

    # Validate unique slugs before proceeding
    validate_unique_slugs(content_result.pages, verbose)

    # Filter drafts if not in draft mode
    pages = filter_drafts(content_result.pages, draft)

    # Step 2b: Filter pages for incremental build
    {pages_to_build, pages_skipped} =
      if incremental && map_size(cache) > 0 do
        filter_changed_pages(pages, cache, config, verbose)
      else
        {pages, []}
      end

    # Step 3: Generate collections
    collections_result = generate_collections(pages, opts, verbose)

    # Step 3b: Generate RSS feed (if enabled)
    rss_file_writer = Keyword.get(opts, :file_writer, &default_file_writer/2)

    rss_mkdir =
      if Keyword.has_key?(opts, :file_writer), do: fn _ -> :ok end, else: &File.mkdir_p!/1

    rss_written = generate_rss_feed(pages, config, rss_file_writer, rss_mkdir, opts, verbose)

    # Step 4: Process assets
    assets_result = process_assets(config, opts, verbose)

    # Step 5: Render and write pages
    pages_written =
      render_and_write_pages(
        pages_to_build,
        config,
        collections_result.collections,
        assets_result.mappings,
        opts,
        verbose
      )

    # Step 5b: Render and write collection pages
    collection_pages_result =
      render_and_write_collection_pages(
        collections_result.collections,
        config,
        assets_result.mappings,
        opts,
        verbose
      )

    # Step 6: Write assets
    assets_written = write_assets(assets_result.assets, config, opts, verbose)

    # Step 7: Update cache for incremental builds
    if incremental do
      # Collect content file paths
      content_file_paths =
        pages
        |> Enum.map(&Map.get(&1, :file_path))
        |> Enum.filter(&(&1 != nil))

      # Collect layout and partial file paths
      layouts_path = Map.get(config, :layouts_path, "layouts")
      site_path_str = Map.get(config, :site_path, ".")

      # Ensure site_path is absolute
      absolute_site_path = Path.expand(site_path_str)

      absolute_layouts_path =
        if Path.type(layouts_path) == :relative do
          Path.join(absolute_site_path, layouts_path)
        else
          layouts_path
        end

      layout_file_paths =
        if File.exists?(absolute_layouts_path) do
          Path.wildcard(Path.join(absolute_layouts_path, "**/*.{html,heex,eex}"))
        else
          []
        end

      # Combine all file paths to track
      all_file_paths = content_file_paths ++ layout_file_paths

      updated_cache = Alkali.Infrastructure.BuildCache.update_cache(cache, all_file_paths)

      Alkali.Infrastructure.BuildCache.save(site_path, updated_cache)
    end

    # Build summary
    summary = %{
      pages: length(pages),
      collections: map_size(collections_result.collections),
      assets: length(assets_result.assets),
      files_written: pages_written + collection_pages_result.total + assets_written + rss_written,
      stats: %{
        total_pages: Map.get(content_result.stats, :total_files, 0),
        drafts: Map.get(content_result.stats, :drafts, 0),
        rendered_pages: pages_written,
        tag_pages: collection_pages_result.tag_pages,
        category_pages: collection_pages_result.category_pages,
        posts_pages: Map.get(collection_pages_result, :posts_pages, 0),
        rss_feed: rss_written,
        incremental: incremental && map_size(cache) > 0,
        changed: length(pages_to_build),
        skipped: length(pages_skipped)
      }
    }

    if verbose do
      rss_info = if rss_written > 0, do: ", RSS feed", else: ""

      IO.puts(
        "Build complete: #{summary.pages} pages, #{summary.collections} collections, #{summary.assets} assets#{rss_info}"
      )
    end

    {:ok, summary}
  rescue
    e in RuntimeError -> {:error, e.message}
  end

  # Private Functions

  defp load_config(site_path, config_loader, verbose) do
    if verbose, do: IO.puts("Loading configuration...")

    case config_loader.(site_path) do
      {:ok, config} ->
        config

      {:error, reason} ->
        raise RuntimeError, "Failed to load config: #{reason}"
    end
  end

  defp parse_content(config, opts, verbose) do
    if verbose, do: IO.puts("Parsing content...")

    content_parser = Keyword.get(opts, :content_parser, &default_content_parser/2)
    content_path = Map.get(config, :content_path, "content")

    # Make content_path absolute if it's relative
    absolute_content_path =
      if Path.type(content_path) == :relative do
        Path.join(Map.get(config, :site_path, "."), content_path)
      else
        content_path
      end

    case content_parser.(absolute_content_path, opts) do
      {:ok, result} ->
        result

      {:error, reason} ->
        raise RuntimeError, "Failed to parse content: #{reason}"
    end
  end

  defp filter_drafts(pages, draft) do
    if draft do
      pages
    else
      Enum.filter(pages, &(not &1.draft))
    end
  end

  defp filter_changed_pages(pages, cache, config, verbose) do
    if verbose, do: IO.puts("Checking for changed files...")

    alias Alkali.Infrastructure.BuildCache

    # Check if any layout files have changed
    layouts_path = Map.get(config, :layouts_path, "layouts")
    site_path = Map.get(config, :site_path, ".")

    # Ensure site_path is absolute
    absolute_site_path = Path.expand(site_path)

    absolute_layouts_path =
      if Path.type(layouts_path) == :relative do
        Path.join(absolute_site_path, layouts_path)
      else
        layouts_path
      end

    layout_files_changed =
      if File.exists?(absolute_layouts_path) do
        layout_files = Path.wildcard(Path.join(absolute_layouts_path, "**/*.{html,heex,eex}"))

        Enum.any?(layout_files, fn layout_file ->
          changed = BuildCache.file_changed?(layout_file, cache)

          if verbose && changed do
            IO.puts("  Layout file changed: #{Path.relative_to_cwd(layout_file)}")
          end

          changed
        end)
      else
        false
      end

    # If any layout file changed, rebuild all pages
    if layout_files_changed do
      if verbose, do: IO.puts("  Layout files changed - rebuilding all pages")
      {pages, []}
    else
      # Otherwise, only rebuild pages whose content files changed
      {changed, skipped} =
        Enum.split_with(pages, fn page ->
          # Check if the source file has changed
          file_path = Map.get(page, :file_path)

          if file_path && File.exists?(file_path) do
            BuildCache.file_changed?(file_path, cache)
          else
            # If no source file or doesn't exist, assume changed
            true
          end
        end)

      if verbose do
        IO.puts("  Changed: #{length(changed)} files")
        IO.puts("  Skipped: #{length(skipped)} files")
      end

      {changed, skipped}
    end
  end

  defp validate_unique_slugs(pages, verbose) do
    slug_counts =
      pages
      |> Enum.group_by(& &1.slug)
      |> Enum.filter(fn {_slug, pages} -> length(pages) > 1 end)

    case slug_counts do
      [] ->
        :ok

      duplicates ->
        duplicate_info =
          Enum.map(duplicates, fn {slug, pages} ->
            files = Enum.map(pages, & &1.file_path) |> Enum.join(", ")
            "  - '#{slug}': #{files}"
          end)
          |> Enum.join("\n")

        message = "Duplicate slug detected:\n#{duplicate_info}"

        if verbose, do: IO.puts("ERROR: #{message}")
        raise RuntimeError, message
    end
  end

  defp generate_collections(pages, opts, verbose) do
    if verbose, do: IO.puts("Generating collections...")

    collections_generator =
      Keyword.get(opts, :collections_generator, &default_collections_generator/2)

    case collections_generator.(pages, opts) do
      {:ok, collections} when is_list(collections) ->
        # Convert list to map format expected by the rest of the code
        collections_map =
          Enum.reduce(collections, %{}, fn collection, acc ->
            Map.put(acc, collection.name, collection)
          end)

        %{collections: collections_map, stats: %{total_collections: length(collections)}}

      {:error, reason} ->
        raise RuntimeError, "Failed to generate collections: #{reason}"
    end
  end

  defp generate_rss_feed(pages, config, file_writer, mkdir_fn, opts, verbose) do
    # Check if RSS generation is enabled (default: true)
    generate_rss = Keyword.get(opts, :generate_rss, true)

    if not generate_rss do
      if verbose, do: IO.puts("Skipping RSS feed generation (disabled)")
      0
    else
      if verbose, do: IO.puts("Generating RSS feed...")

      # Check if site_url is configured
      site_url = Map.get(config, :site_url)

      if is_nil(site_url) or site_url == "" do
        if verbose, do: IO.puts("  Warning: site_url not configured, skipping RSS feed")
        0
      else
        # Generate RSS feed
        rss_opts = [
          site_url: site_url,
          feed_title: Map.get(config, :site_name, "Blog"),
          feed_description: Map.get(config, :description, "Latest posts"),
          max_items: Keyword.get(opts, :rss_max_items, 20)
        ]

        case Alkali.Application.UseCases.GenerateRssFeed.execute(pages, rss_opts) do
          {:ok, xml} ->
            # Write RSS feed to output directory
            output_path = Map.get(config, :output_path, "_site")

            absolute_output_path =
              if Path.type(output_path) == :relative do
                Path.join(Map.get(config, :site_path, "."), output_path)
              else
                output_path
              end

            feed_path = Path.join(absolute_output_path, "feed.xml")
            mkdir_fn.(Path.dirname(feed_path))

            case file_writer.(feed_path, xml) do
              :ok ->
                if verbose, do: IO.puts("  Written: feed.xml")
                1

              {:ok, _} ->
                if verbose, do: IO.puts("  Written: feed.xml")
                1

              {:error, reason} ->
                if verbose,
                  do: IO.puts("  Warning: Failed to write RSS feed: #{inspect(reason)}")

                0
            end

          {:error, reason} ->
            if verbose,
              do: IO.puts("  Warning: Failed to generate RSS feed: #{inspect(reason)}")

            0
        end
      end
    end
  end

  defp process_assets(config, opts, verbose) do
    if verbose, do: IO.puts("Processing assets...")

    assets_processor = Keyword.get(opts, :assets_processor, &default_assets_processor/2)

    # Use site_path from config if available, otherwise use "."
    site_path = Map.get(config, :site_path, ".")
    assets_path = Path.join(site_path, "static")

    # Discover all files recursively in static/ directory
    assets =
      if File.dir?(assets_path) do
        discover_assets(assets_path, "static")
      else
        []
      end

    case assets_processor.(assets, opts) do
      {:ok, result} ->
        result

      {:error, reason} ->
        raise RuntimeError, "Failed to process assets: #{reason}"
    end
  end

  defp discover_assets(base_path, _relative_base) do
    base_path
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(fn file_path ->
      # Calculate relative path from the static/ directory
      relative_path = Path.relative_to(file_path, base_path)

      # Determine asset type based on extension
      type =
        case Path.extname(file_path) do
          ".css" -> :css
          ".js" -> :js
          _ -> :binary
        end

      %{
        original_path: file_path,
        output_path: relative_path,
        type: type
      }
    end)
  end

  defp render_and_write_pages(pages, config, collections, mappings, opts, verbose) do
    alias Alkali.Infrastructure.LayoutResolver

    template_renderer = Keyword.get(opts, :template_renderer, &default_template_renderer/3)
    layout_resolver = Keyword.get(opts, :layout_resolver, &LayoutResolver.resolve_layout/3)

    render_with_layout =
      Keyword.get(opts, :render_with_layout, &LayoutResolver.render_with_layout/4)

    file_writer = Keyword.get(opts, :file_writer, &default_file_writer/2)
    output_path = Map.get(config, :output_path, "_site")

    # Make output_path absolute if it's relative
    absolute_output_path =
      if Path.type(output_path) == :relative do
        Path.join(Map.get(config, :site_path, "."), output_path)
      else
        output_path
      end

    Enum.reduce(pages, 0, fn page, count ->
      if verbose, do: IO.puts("  Rendering: #{page.url}")

      # If we have a custom template_renderer, use the old flow for backward compatibility
      result =
        if Keyword.has_key?(opts, :template_renderer) do
          assigns = %{
            page: page,
            site: config,
            collections: collections,
            assets: mappings
          }

          template_renderer.("layout.html.heex", assigns, opts)
        else
          # Use new layout resolution flow
          with {:ok, layout_path} <- layout_resolver.(page, config, opts) do
            # Page already has content field with HTML - no need to merge
            # Just ensure content field exists (it should from ParseContent)

            # Render with layout
            render_opts = [
              assigns: %{collections: collections, assets: mappings},
              asset_mappings: mappings
            ]

            render_with_layout.(page, layout_path, config, render_opts)
          end
        end

      case result do
        {:ok, html} ->
          # Calculate output path from URL
          # URL is like "/posts/2024/my-post", output should be "_site/posts/2024/my-post.html"
          relative_path = String.trim_leading(page.url, "/")

          # Ensure .html extension
          output_file_path =
            if String.ends_with?(relative_path, ".html") do
              relative_path
            else
              relative_path <> ".html"
            end

          output_file = Path.join([absolute_output_path, output_file_path])
          output_dir = Path.dirname(output_file)

          # Ensure directory exists
          File.mkdir_p!(output_dir)

          case file_writer.(output_file, html) do
            :ok -> count + 1
            {:ok, _} -> count + 1
            {:error, _} -> count
          end

        {:error, reason} ->
          # Layout errors and rendering errors should fail the build
          raise RuntimeError, "Failed to render page #{page.url}: #{reason}"
      end
    end)
  end

  defp render_and_write_collection_pages(collections, config, mappings, opts, verbose) do
    if verbose, do: IO.puts("Rendering collection pages...")

    file_writer = Keyword.get(opts, :file_writer, &default_file_writer/2)
    output_path = Map.get(config, :output_path, "_site")

    # Get pagination options
    # nil means no pagination
    posts_per_page = Keyword.get(opts, :posts_per_page, nil)
    # Which collections to paginate
    paginate_collections = Keyword.get(opts, :paginate_collections, [:posts])

    # Make output_path absolute if it's relative
    absolute_output_path =
      if Path.type(output_path) == :relative do
        Path.join(Map.get(config, :site_path, "."), output_path)
      else
        output_path
      end

    # Render each collection as a page (or multiple paginated pages)
    # Filter to only collections with a type field (tag, category, or posts)
    result =
      collections
      |> Map.values()
      |> Enum.filter(fn collection ->
        Map.has_key?(collection, :type) && collection.type in [:tag, :category, :posts]
      end)
      |> Enum.reduce(%{tag_pages: 0, category_pages: 0, posts_pages: 0, total: 0}, fn collection,
                                                                                      acc ->
        if verbose, do: IO.puts("  Rendering collection: #{collection.name} (#{collection.type})")

        # Check if this collection should be paginated
        should_paginate =
          posts_per_page != nil &&
            collection.type in paginate_collections &&
            length(collection.pages) > posts_per_page

        if should_paginate do
          # Render paginated collection pages
          render_paginated_collection(
            collection,
            posts_per_page,
            config,
            mappings,
            opts,
            absolute_output_path,
            file_writer,
            acc,
            verbose
          )
        else
          # Render single collection page (existing behavior)
          render_single_collection_page(
            collection,
            config,
            mappings,
            opts,
            absolute_output_path,
            file_writer,
            acc,
            verbose
          )
        end
      end)

    result
  end

  defp render_single_collection_page(
         collection,
         config,
         mappings,
         opts,
         absolute_output_path,
         file_writer,
         acc,
         _verbose
       ) do
    # Determine output path based on collection type
    # Tags -> /tags/{name}.html
    # Categories -> /categories/{name}.html
    # Posts -> /posts/index.html
    {collection_dir, filename} =
      case collection.type do
        :tag -> {"tags", "#{collection.name}.html"}
        :category -> {"categories", "#{collection.name}.html"}
        :posts -> {"posts", "index.html"}
        _ -> {"#{collection.type}s", "#{collection.name}.html"}
      end

    output_file_path = Path.join([collection_dir, filename])
    output_file = Path.join([absolute_output_path, output_file_path])
    output_dir = Path.dirname(output_file)

    # Ensure directory exists
    File.mkdir_p!(output_dir)

    # Generate HTML content for collection page (no pagination)
    html = render_collection_page(collection, config, mappings, opts, nil)

    case file_writer.(output_file, html) do
      :ok ->
        # Update counters based on type
        case collection.type do
          :tag -> %{acc | tag_pages: acc.tag_pages + 1, total: acc.total + 1}
          :category -> %{acc | category_pages: acc.category_pages + 1, total: acc.total + 1}
          :posts -> %{acc | posts_pages: acc.posts_pages + 1, total: acc.total + 1}
          _ -> %{acc | total: acc.total + 1}
        end

      {:ok, _} ->
        case collection.type do
          :tag -> %{acc | tag_pages: acc.tag_pages + 1, total: acc.total + 1}
          :category -> %{acc | category_pages: acc.category_pages + 1, total: acc.total + 1}
          :posts -> %{acc | posts_pages: acc.posts_pages + 1, total: acc.total + 1}
          _ -> %{acc | total: acc.total + 1}
        end

      {:error, _} ->
        acc
    end
  end

  defp render_paginated_collection(
         collection,
         per_page,
         config,
         mappings,
         opts,
         absolute_output_path,
         file_writer,
         acc,
         verbose
       ) do
    alias Alkali.Application.Helpers.Paginate

    # Determine base path for URLs based on collection type
    base_path =
      case collection.type do
        :tag -> "/tags/#{collection.name}"
        :category -> "/categories/#{collection.name}"
        :posts -> "/posts"
        _ -> "/#{collection.type}s/#{collection.name}"
      end

    url_template = "#{base_path}/page/:page"

    # Paginate the collection items
    paginated_pages =
      Paginate.paginate(collection.pages, per_page: per_page, url_template: url_template)

    # Render each paginated page
    Enum.reduce(paginated_pages, acc, fn page, page_acc ->
      if verbose do
        IO.puts("    Page #{page.page_number}/#{page.pagination.total_pages}")
      end

      # Determine output file path
      {collection_dir, filename} =
        case collection.type do
          :posts when page.page_number == 1 -> {"posts", "index.html"}
          :posts -> {"posts", "page/#{page.page_number}.html"}
          :tag when page.page_number == 1 -> {"tags", "#{collection.name}.html"}
          :tag -> {"tags", "#{collection.name}/page/#{page.page_number}.html"}
          :category when page.page_number == 1 -> {"categories", "#{collection.name}.html"}
          :category -> {"categories", "#{collection.name}/page/#{page.page_number}.html"}
          _ when page.page_number == 1 -> {"#{collection.type}s", "#{collection.name}.html"}
          _ -> {"#{collection.type}s", "#{collection.name}/page/#{page.page_number}.html"}
        end

      output_file_path = Path.join([collection_dir, filename])
      output_file = Path.join([absolute_output_path, output_file_path])
      output_dir = Path.dirname(output_file)

      # Ensure directory exists
      File.mkdir_p!(output_dir)

      # Create a modified collection with just this page's items
      page_collection = %{collection | pages: page.items}

      # Generate HTML content with pagination metadata
      html = render_collection_page(page_collection, config, mappings, opts, page.pagination)

      case file_writer.(output_file, html) do
        :ok ->
          # Update counters based on type
          case collection.type do
            :tag ->
              %{page_acc | tag_pages: page_acc.tag_pages + 1, total: page_acc.total + 1}

            :category ->
              %{page_acc | category_pages: page_acc.category_pages + 1, total: page_acc.total + 1}

            :posts ->
              %{page_acc | posts_pages: page_acc.posts_pages + 1, total: page_acc.total + 1}

            _ ->
              %{page_acc | total: page_acc.total + 1}
          end

        {:ok, _} ->
          case collection.type do
            :tag ->
              %{page_acc | tag_pages: page_acc.tag_pages + 1, total: page_acc.total + 1}

            :category ->
              %{page_acc | category_pages: page_acc.category_pages + 1, total: page_acc.total + 1}

            :posts ->
              %{page_acc | posts_pages: page_acc.posts_pages + 1, total: page_acc.total + 1}

            _ ->
              %{page_acc | total: page_acc.total + 1}
          end

        {:error, _} ->
          page_acc
      end
    end)
  end

  defp render_collection_page(collection, config, mappings, _opts, pagination) do
    alias Alkali.Infrastructure.LayoutResolver

    # Create a simple HTML page listing all posts in the collection
    # Convert absolute URLs to relative URLs (collections are one level deep)
    posts_html =
      collection.pages
      |> Enum.map(fn page ->
        # Convert /posts/welcome.html to ../posts/welcome.html
        relative_url = String.trim_leading(page.url, "/")
        relative_url = if relative_url != "", do: "../#{relative_url}", else: "../index.html"

        # Format date nicely
        formatted_date =
          if page.date do
            Calendar.strftime(page.date, "%B %d, %Y")
          else
            ""
          end

        # Get intro text from frontmatter
        intro =
          case page do
            %{frontmatter: fm} when is_map(fm) ->
              Map.get(fm, "intro") || Map.get(fm, "description") || ""

            _ ->
              ""
          end

        intro_html =
          if intro != "" do
            ~s(<p class="post-intro">#{intro}</p>)
          else
            ""
          end

        """
        <article class="post-item">
          <h3 class="post-title"><a href="#{relative_url}">#{page.title}</a></h3>
          #{intro_html}
          #{if formatted_date != "", do: "<time class=\"post-date\">#{formatted_date}</time>", else: ""}
        </article>
        """
      end)
      |> Enum.join("\n")

    # Build pagination HTML if pagination metadata provided
    pagination_html =
      if pagination do
        build_pagination_html(pagination)
      else
        ""
      end

    # Customize content based on collection type
    {title, content} =
      case collection.type do
        :posts ->
          page_info =
            if pagination do
              " (Page #{pagination.current_page} of #{pagination.total_pages})"
            else
              ""
            end

          {"All Posts#{page_info}",
           """
           <p class="collection-meta">Total posts: #{length(collection.pages)}</p>
           <div class="posts">
             #{posts_html}
           </div>
           #{pagination_html}
           """}

        :tag ->
          page_info =
            if pagination do
              " (Page #{pagination.current_page} of #{pagination.total_pages})"
            else
              ""
            end

          {"#{String.capitalize(to_string(collection.type))}: #{collection.name}#{page_info}",
           """
           <p class="collection-meta">Posts: #{length(collection.pages)}</p>
           <div class="posts">
             #{posts_html}
           </div>
           #{pagination_html}
           """}

        :category ->
          page_info =
            if pagination do
              " (Page #{pagination.current_page} of #{pagination.total_pages})"
            else
              ""
            end

          {"#{String.capitalize(to_string(collection.type))}: #{collection.name}#{page_info}",
           """
           <p class="collection-meta">Posts: #{length(collection.pages)}</p>
           <div class="posts">
             #{posts_html}
           </div>
           #{pagination_html}
           """}

        _ ->
          {"#{String.capitalize(to_string(collection.type))}: #{collection.name}",
           """
           <p class="collection-meta">Posts: #{length(collection.pages)}</p>
           <div class="posts">
             #{posts_html}
           </div>
           """}
      end

    # Determine output path based on collection type
    url_path =
      case collection.type do
        :tag -> "/tags/#{collection.name}.html"
        :category -> "/categories/#{collection.name}.html"
        :posts -> "/posts/index.html"
        _ -> "/#{collection.type}s/#{collection.name}.html"
      end

    # Create a pseudo-page for layout resolution
    page = %{
      title: title,
      content: content,
      url: url_path,
      layout: "collection"
    }

    # Try to find and use a layout
    layouts_path = Map.get(config, :layouts_path, "layouts")
    site_path = Map.get(config, :site_path, ".")

    absolute_layouts_path =
      if Path.type(layouts_path) == :relative do
        Path.join(site_path, layouts_path)
      else
        layouts_path
      end

    # Try collection-specific layout first, then default
    layout_candidates = [
      Path.join(absolute_layouts_path, "#{collection.type}.html.heex"),
      Path.join(absolute_layouts_path, "collection.html.heex"),
      Path.join(absolute_layouts_path, "default.html.heex")
    ]

    layout_path = Enum.find(layout_candidates, &File.exists?/1)

    if layout_path do
      # Use LayoutResolver to get asset fingerprinting
      render_opts = [
        asset_mappings: mappings
      ]

      case LayoutResolver.render_with_layout(page, layout_path, config, render_opts) do
        {:ok, html} -> html
        {:error, _} -> content
      end
    else
      # No layout found, use bare content
      content
    end
  end

  defp build_pagination_html(pagination) do
    # Build previous link
    prev_link =
      if pagination.has_prev do
        prev_url = pagination.prev_url || "../index.html"
        ~s(<a href="#{prev_url}" class="pagination-prev">← Previous</a>)
      else
        ~s(<span class="pagination-prev disabled">← Previous</span>)
      end

    # Build next link
    next_link =
      if pagination.has_next do
        ~s(<a href="#{pagination.next_url}" class="pagination-next">Next →</a>)
      else
        ~s(<span class="pagination-next disabled">Next →</span>)
      end

    # Build page number links
    page_links =
      Enum.map(pagination.page_numbers, fn page_num ->
        url = if page_num == 1, do: "../index.html", else: "../page/#{page_num}.html"

        if page_num == pagination.current_page do
          ~s(<span class="pagination-page current">#{page_num}</span>)
        else
          ~s(<a href="#{url}" class="pagination-page">#{page_num}</a>)
        end
      end)
      |> Enum.join(" ")

    """
    <nav class="pagination">
      #{prev_link}
      <span class="pagination-pages">#{page_links}</span>
      #{next_link}
    </nav>
    """
  end

  defp write_assets(assets, config, opts, verbose) do
    asset_writer = Keyword.get(opts, :asset_writer, &default_asset_writer/2)
    output_path = Map.get(config, :output_path, "_site")

    # Make output_path absolute if it's relative
    absolute_output_path =
      if Path.type(output_path) == :relative do
        Path.join(Map.get(config, :site_path, "."), output_path)
      else
        output_path
      end

    Enum.reduce(assets, 0, fn asset, count ->
      if verbose, do: IO.puts("  Writing asset: #{asset.output_path}")

      # Use the minified content stored in the asset
      content = asset.content || ""

      output_file = Path.join(absolute_output_path, asset.output_path)
      output_dir = Path.dirname(output_file)

      File.mkdir_p!(output_dir)

      case asset_writer.(output_file, content) do
        {:ok, _} -> count + 1
        {:error, _} -> count
      end
    end)
  end

  # Default implementations

  defp default_config_loader(site_path) do
    alias Alkali.Infrastructure.ConfigLoader
    ConfigLoader.load(site_path)
  end

  defp default_content_parser(path, opts) do
    alias Alkali.Application.UseCases.ParseContent
    ParseContent.execute(path, opts)
  end

  defp default_collections_generator(pages, opts) do
    alias Alkali.Application.UseCases.GenerateCollections
    GenerateCollections.execute(pages, opts)
  end

  defp default_assets_processor(assets, opts) do
    alias Alkali.Application.UseCases.ProcessAssets
    ProcessAssets.execute(assets, opts)
  end

  defp default_template_renderer(_layout, _assigns, _opts) do
    {:ok, "<html></html>"}
  end

  defp default_file_writer(path, content) do
    File.write(path, content)
  end

  defp default_asset_writer(path, content) do
    case File.write(path, content) do
      :ok -> {:ok, path}
      error -> error
    end
  end
end
