defmodule Alkali.Application.UseCases.BuildSite do
  @moduledoc """
  BuildSite use case orchestrates the full static site build process.
  """

  alias Alkali.Application.UseCases.GenerateRssFeed
  alias Alkali.Infrastructure.BuildCache
  alias Alkali.Infrastructure.FileSystem
  alias Alkali.Infrastructure.LayoutResolver

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
    file_system = Keyword.get(opts, :file_system, Alkali.Infrastructure.FileSystem)

    # Step 0: Load build cache for incremental builds
    cache = load_build_cache(site_path, incremental, verbose)
    opts = Keyword.put(opts, :file_system, file_system)

    # Step 1: Load config
    config = load_config(site_path, config_loader, verbose)
    config = Map.put_new(config, :site_path, site_path)

    # Step 2: Parse content
    content_result = parse_content(config, opts, verbose)
    validate_unique_slugs(content_result.pages, verbose)
    pages = filter_drafts(content_result.pages, draft)

    # Step 2b: Filter pages for incremental build
    {pages_to_build, pages_skipped} =
      filter_for_incremental_build(pages, cache, config, verbose, file_system)

    # Step 3: Generate collections
    collections_result = generate_collections(pages, opts, verbose)

    # Step 3b: Generate RSS feed (if enabled)
    rss_written = generate_rss(pages, config, opts, verbose)

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
    if incremental, do: update_build_cache(cache, pages, config, site_path, file_system)

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

  defp load_build_cache(site_path, true, verbose) do
    if verbose, do: IO.puts("Loading build cache...")
    BuildCache.load(site_path)
  end

  defp load_build_cache(_site_path, false, _verbose), do: %{}

  defp filter_for_incremental_build(pages, cache, config, verbose, file_system)
       when map_size(cache) > 0 do
    filter_changed_pages(pages, cache, config, verbose, file_system)
  end

  defp filter_for_incremental_build(pages, _cache, _config, _verbose, _file_system),
    do: {pages, []}

  defp generate_rss(pages, config, opts, verbose) do
    rss_file_writer = Keyword.get(opts, :file_writer, &default_file_writer/2)
    file_system = Keyword.get(opts, :file_system, Alkali.Infrastructure.FileSystem)

    rss_mkdir =
      if Keyword.has_key?(opts, :file_writer), do: fn _ -> :ok end, else: &file_system.mkdir_p!/1

    generate_rss_feed(pages, config, rss_file_writer, rss_mkdir, opts, verbose)
  end

  defp update_build_cache(cache, pages, config, site_path, file_system) do
    content_file_paths =
      pages
      |> Enum.map(&Map.get(&1, :file_path))
      |> Enum.filter(&(&1 != nil))

    layout_file_paths = collect_layout_file_paths(config, file_system)

    all_file_paths = content_file_paths ++ layout_file_paths
    updated_cache = BuildCache.update_cache(cache, all_file_paths)
    BuildCache.save(site_path, updated_cache)
  end

  defp collect_layout_file_paths(config, file_system) do
    layouts_path = Map.get(config, :layouts_path, "layouts")
    site_path_str = Map.get(config, :site_path, ".")
    absolute_site_path = Path.expand(site_path_str)

    absolute_layouts_path =
      if Path.type(layouts_path) == :relative,
        do: Path.join(absolute_site_path, layouts_path),
        else: layouts_path

    if file_system.exists?(absolute_layouts_path) do
      file_system.wildcard(Path.join(absolute_layouts_path, "**/*.{html,heex,eex}"))
    else
      []
    end
  end

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

  defp filter_changed_pages(pages, cache, config, verbose, file_system) do
    if verbose, do: IO.puts("Checking for changed files...")

    absolute_layouts_path = get_absolute_layouts_path(config)

    if layout_files_changed?(absolute_layouts_path, cache, verbose, file_system) do
      if verbose, do: IO.puts("  Layout files changed - rebuilding all pages")
      {pages, []}
    else
      split_pages_by_change_status(pages, cache, verbose, file_system)
    end
  end

  defp get_absolute_layouts_path(config) do
    layouts_path = Map.get(config, :layouts_path, "layouts")
    site_path = Map.get(config, :site_path, ".")
    absolute_site_path = Path.expand(site_path)

    if Path.type(layouts_path) == :relative do
      Path.join(absolute_site_path, layouts_path)
    else
      layouts_path
    end
  end

  defp layout_files_changed?(absolute_layouts_path, cache, verbose, file_system) do
    if file_system.exists?(absolute_layouts_path) do
      layout_files =
        file_system.wildcard(Path.join(absolute_layouts_path, "**/*.{html,heex,eex}"))

      Enum.any?(layout_files, &layout_file_changed?(&1, cache, verbose))
    else
      false
    end
  end

  defp layout_file_changed?(layout_file, cache, verbose) do
    changed = BuildCache.file_changed?(layout_file, cache)

    if verbose && changed do
      IO.puts("  Layout file changed: #{Path.relative_to_cwd(layout_file)}")
    end

    changed
  end

  defp split_pages_by_change_status(pages, cache, verbose, file_system) do
    {changed, skipped} =
      Enum.split_with(pages, &page_changed?(&1, cache, file_system))

    if verbose do
      IO.puts("  Changed: #{length(changed)} files")
      IO.puts("  Skipped: #{length(skipped)} files")
    end

    {changed, skipped}
  end

  defp page_changed?(page, cache, file_system) do
    file_path = Map.get(page, :file_path)

    if file_path && file_system.exists?(file_path) do
      BuildCache.file_changed?(file_path, cache)
    else
      true
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
          Enum.map_join(duplicates, "\n", fn {slug, pages} ->
            files = Enum.map_join(pages, ", ", & &1.file_path)
            "  - '#{slug}': #{files}"
          end)

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
    if Keyword.get(opts, :generate_rss, true) do
      do_generate_rss_feed(pages, config, file_writer, mkdir_fn, opts, verbose)
    else
      if verbose, do: IO.puts("Skipping RSS feed generation (disabled)")
      0
    end
  end

  defp do_generate_rss_feed(pages, config, file_writer, mkdir_fn, opts, verbose) do
    if verbose, do: IO.puts("Generating RSS feed...")

    site_url = Map.get(config, :site_url)

    if is_nil(site_url) or site_url == "" do
      if verbose, do: IO.puts("  Warning: site_url not configured, skipping RSS feed")
      0
    else
      generate_and_write_rss_feed(pages, config, file_writer, mkdir_fn, opts, verbose, site_url)
    end
  end

  defp generate_and_write_rss_feed(pages, config, file_writer, mkdir_fn, opts, verbose, site_url) do
    rss_opts = [
      site_url: site_url,
      feed_title: Map.get(config, :site_name, "Blog"),
      feed_description: Map.get(config, :description, "Latest posts"),
      max_items: Keyword.get(opts, :rss_max_items, 20)
    ]

    case GenerateRssFeed.execute(pages, rss_opts) do
      {:ok, xml} ->
        write_rss_feed_to_disk(config, file_writer, mkdir_fn, verbose, xml)

      {:error, reason} ->
        if verbose,
          do: IO.puts("  Warning: Failed to generate RSS feed: #{inspect(reason)}")

        0
    end
  end

  defp write_rss_feed_to_disk(config, file_writer, mkdir_fn, verbose, xml) do
    output_path = Map.get(config, :output_path, "_site")
    absolute_output_path = get_absolute_output_path(config, output_path)
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
  end

  defp get_absolute_output_path(config, output_path) do
    if Path.type(output_path) == :relative do
      Path.join(Map.get(config, :site_path, "."), output_path)
    else
      output_path
    end
  end

  defp process_assets(config, opts, verbose) do
    if verbose, do: IO.puts("Processing assets...")

    assets_processor = Keyword.get(opts, :assets_processor, &default_assets_processor/2)
    file_system = Keyword.get(opts, :file_system, Alkali.Infrastructure.FileSystem)

    # Use site_path from config if available, otherwise use "."
    site_path = Map.get(config, :site_path, ".")
    assets_path = Path.join(site_path, "static")

    # Discover all files recursively in static/ directory
    assets =
      if file_system.dir?(assets_path) do
        discover_assets(assets_path, "static", file_system)
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

  defp discover_assets(base_path, _relative_base, file_system) do
    base_path
    |> Path.join("**/*")
    |> file_system.wildcard()
    |> Enum.filter(&file_system.regular?/1)
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
    render_ctx = build_render_context(config, collections, mappings, opts)

    Enum.reduce(pages, 0, fn page, count ->
      if verbose, do: IO.puts("  Rendering: #{page.url}")
      render_and_write_single_page(page, render_ctx, count)
    end)
  end

  defp build_render_context(config, collections, mappings, opts) do
    output_path = Map.get(config, :output_path, "_site")

    absolute_output_path =
      if Path.type(output_path) == :relative do
        Path.join(Map.get(config, :site_path, "."), output_path)
      else
        output_path
      end

    %{
      template_renderer: Keyword.get(opts, :template_renderer, &default_template_renderer/3),
      layout_resolver: Keyword.get(opts, :layout_resolver, &LayoutResolver.resolve_layout/3),
      render_with_layout:
        Keyword.get(opts, :render_with_layout, &LayoutResolver.render_with_layout/4),
      file_writer: Keyword.get(opts, :file_writer, &default_file_writer/2),
      file_system: Keyword.get(opts, :file_system, Alkali.Infrastructure.FileSystem),
      absolute_output_path: absolute_output_path,
      config: config,
      collections: collections,
      mappings: mappings,
      opts: opts,
      has_custom_renderer: Keyword.has_key?(opts, :template_renderer)
    }
  end

  defp render_and_write_single_page(page, ctx, count) do
    result = render_page_html(page, ctx)
    handle_render_result(result, page, ctx, count)
  end

  defp render_page_html(page, %{has_custom_renderer: true} = ctx) do
    assigns = %{
      page: page,
      site: ctx.config,
      collections: ctx.collections,
      assets: ctx.mappings
    }

    ctx.template_renderer.("layout.html.heex", assigns, ctx.opts)
  end

  defp render_page_html(page, ctx) do
    with {:ok, layout_path} <- ctx.layout_resolver.(page, ctx.config, ctx.opts) do
      render_opts = [
        assigns: %{collections: ctx.collections, assets: ctx.mappings},
        asset_mappings: ctx.mappings
      ]

      ctx.render_with_layout.(page, layout_path, ctx.config, render_opts)
    end
  end

  defp handle_render_result({:ok, html}, page, ctx, count) do
    output_file = build_output_path(page.url, ctx.absolute_output_path)
    output_dir = Path.dirname(output_file)
    ctx.file_system.mkdir_p!(output_dir)

    case ctx.file_writer.(output_file, html) do
      :ok -> count + 1
      {:ok, _} -> count + 1
      {:error, _} -> count
    end
  end

  defp handle_render_result({:error, reason}, page, _ctx, _count) do
    raise RuntimeError, "Failed to render page #{page.url}: #{reason}"
  end

  defp build_output_path(url, absolute_output_path) do
    relative_path = String.trim_leading(url, "/")

    output_file_path =
      if String.ends_with?(relative_path, ".html"),
        do: relative_path,
        else: relative_path <> ".html"

    Path.join([absolute_output_path, output_file_path])
  end

  defp render_and_write_collection_pages(collections, config, mappings, opts, verbose) do
    if verbose, do: IO.puts("Rendering collection pages...")

    ctx = build_collection_render_context(config, mappings, opts)

    collections
    |> Map.values()
    |> Enum.filter(&valid_collection?/1)
    |> Enum.reduce(%{tag_pages: 0, category_pages: 0, posts_pages: 0, total: 0}, fn collection,
                                                                                    acc ->
      if verbose, do: IO.puts("  Rendering collection: #{collection.name} (#{collection.type})")
      render_collection(collection, ctx, acc, verbose)
    end)
  end

  defp build_collection_render_context(config, mappings, opts) do
    output_path = Map.get(config, :output_path, "_site")

    absolute_output_path =
      if Path.type(output_path) == :relative,
        do: Path.join(Map.get(config, :site_path, "."), output_path),
        else: output_path

    %{
      config: config,
      mappings: mappings,
      opts: opts,
      file_writer: Keyword.get(opts, :file_writer, &default_file_writer/2),
      file_system: Keyword.get(opts, :file_system, Alkali.Infrastructure.FileSystem),
      absolute_output_path: absolute_output_path,
      posts_per_page: Keyword.get(opts, :posts_per_page, nil),
      paginate_collections: Keyword.get(opts, :paginate_collections, [:posts])
    }
  end

  defp valid_collection?(collection) do
    Map.has_key?(collection, :type) && collection.type in [:tag, :category, :posts]
  end

  defp render_collection(collection, ctx, acc, verbose) do
    should_paginate =
      ctx.posts_per_page != nil and
        collection.type in ctx.paginate_collections and
        Enum.count(collection.pages) > ctx.posts_per_page

    if should_paginate do
      render_paginated_collection(collection, ctx.posts_per_page, ctx, acc, verbose)
    else
      render_single_collection_page(collection, ctx, acc)
    end
  end

  defp render_single_collection_page(collection, ctx, acc) do
    {collection_dir, filename} = single_collection_output_path(collection)

    output_file_path = Path.join([collection_dir, filename])
    output_file = Path.join([ctx.absolute_output_path, output_file_path])
    output_dir = Path.dirname(output_file)
    ctx.file_system.mkdir_p!(output_dir)

    html =
      render_collection_page(collection, ctx.config, ctx.mappings, ctx.opts, nil, ctx.file_system)

    case ctx.file_writer.(output_file, html) do
      :ok -> increment_collection_counter(acc, collection.type)
      {:ok, _} -> increment_collection_counter(acc, collection.type)
      {:error, _} -> acc
    end
  end

  defp single_collection_output_path(collection) do
    case collection.type do
      :tag -> {"tags", "#{collection.name}.html"}
      :category -> {"categories", "#{collection.name}.html"}
      :posts -> {"posts", "index.html"}
      _ -> {"#{collection.type}s", "#{collection.name}.html"}
    end
  end

  defp render_paginated_collection(collection, per_page, ctx, acc, verbose) do
    alias Alkali.Application.Helpers.Paginate

    base_path = pagination_base_path(collection)
    url_template = "#{base_path}/page/:page"

    paginated_pages =
      Paginate.paginate(collection.pages, per_page: per_page, url_template: url_template)

    Enum.reduce(paginated_pages, acc, fn page, page_acc ->
      if verbose, do: IO.puts("    Page #{page.page_number}/#{page.pagination.total_pages}")
      render_single_paginated_page(collection, page, ctx, page_acc)
    end)
  end

  defp pagination_base_path(collection) do
    case collection.type do
      :tag -> "/tags/#{collection.name}"
      :category -> "/categories/#{collection.name}"
      :posts -> "/posts"
      _ -> "/#{collection.type}s/#{collection.name}"
    end
  end

  defp render_single_paginated_page(collection, page, ctx, acc) do
    {collection_dir, filename} = paginated_output_path(collection, page.page_number)

    output_file_path = Path.join([collection_dir, filename])
    output_file = Path.join([ctx.absolute_output_path, output_file_path])
    output_dir = Path.dirname(output_file)
    ctx.file_system.mkdir_p!(output_dir)

    page_collection = %{collection | pages: page.items}

    html =
      render_collection_page(
        page_collection,
        ctx.config,
        ctx.mappings,
        ctx.opts,
        page.pagination,
        ctx.file_system
      )

    case ctx.file_writer.(output_file, html) do
      :ok -> increment_collection_counter(acc, collection.type)
      {:ok, _} -> increment_collection_counter(acc, collection.type)
      {:error, _} -> acc
    end
  end

  defp paginated_output_path(collection, page_number) do
    case {collection.type, page_number} do
      {:posts, 1} -> {"posts", "index.html"}
      {:posts, n} -> {"posts", "page/#{n}.html"}
      {:tag, 1} -> {"tags", "#{collection.name}.html"}
      {:tag, n} -> {"tags", "#{collection.name}/page/#{n}.html"}
      {:category, 1} -> {"categories", "#{collection.name}.html"}
      {:category, n} -> {"categories", "#{collection.name}/page/#{n}.html"}
      {type, 1} -> {"#{type}s", "#{collection.name}.html"}
      {type, n} -> {"#{type}s", "#{collection.name}/page/#{n}.html"}
    end
  end

  defp increment_collection_counter(acc, :tag) do
    %{acc | tag_pages: acc.tag_pages + 1, total: acc.total + 1}
  end

  defp increment_collection_counter(acc, :category) do
    %{acc | category_pages: acc.category_pages + 1, total: acc.total + 1}
  end

  defp increment_collection_counter(acc, :posts) do
    %{acc | posts_pages: acc.posts_pages + 1, total: acc.total + 1}
  end

  defp increment_collection_counter(acc, _other) do
    %{acc | total: acc.total + 1}
  end

  defp render_collection_page(collection, config, mappings, _opts, pagination, file_system) do
    posts_html = build_posts_html(collection.pages)
    pagination_html = if pagination, do: build_pagination_html(pagination), else: ""

    {title, content} =
      build_collection_content(collection, posts_html, pagination_html, pagination)

    url_path = collection_url_path(collection)

    page = %{title: title, content: content, url: url_path, layout: "collection"}

    render_collection_with_layout(page, content, collection, config, mappings, file_system)
  end

  defp build_posts_html(pages) do
    Enum.map_join(pages, "\n", &render_post_item/1)
  end

  defp render_post_item(page) do
    relative_url = build_relative_url(page.url)
    formatted_date = format_post_date(page.date)
    intro = extract_intro(page)

    intro_html = if intro != "", do: ~s(<p class="post-intro">#{intro}</p>), else: ""

    date_html =
      if formatted_date != "", do: ~s(<time class="post-date">#{formatted_date}</time>), else: ""

    """
    <article class="post-item">
      <h3 class="post-title"><a href="#{relative_url}">#{page.title}</a></h3>
      #{intro_html}
      #{date_html}
    </article>
    """
  end

  defp build_relative_url(url) do
    relative = String.trim_leading(url, "/")
    if relative != "", do: "../#{relative}", else: "../index.html"
  end

  defp format_post_date(nil), do: ""
  defp format_post_date(date), do: Calendar.strftime(date, "%B %d, %Y")

  defp extract_intro(%{frontmatter: fm}) when is_map(fm) do
    Map.get(fm, "intro") || Map.get(fm, "description") || ""
  end

  defp extract_intro(_), do: ""

  defp build_collection_content(collection, posts_html, pagination_html, pagination) do
    page_info = pagination_page_info(pagination)
    count = Enum.count(collection.pages)

    case collection.type do
      :posts ->
        {"All Posts#{page_info}",
         collection_html("Total posts: #{count}", posts_html, pagination_html)}

      type when type in [:tag, :category] ->
        type_name = String.capitalize(to_string(type))

        {"#{type_name}: #{collection.name}#{page_info}",
         collection_html("Posts: #{count}", posts_html, pagination_html)}

      _ ->
        type_name = String.capitalize(to_string(collection.type))
        {"#{type_name}: #{collection.name}", collection_html("Posts: #{count}", posts_html, "")}
    end
  end

  defp pagination_page_info(nil), do: ""
  defp pagination_page_info(p), do: " (Page #{p.current_page} of #{p.total_pages})"

  defp collection_html(meta, posts_html, pagination_html) do
    """
    <p class="collection-meta">#{meta}</p>
    <div class="posts">
      #{posts_html}
    </div>
    #{pagination_html}
    """
  end

  defp collection_url_path(collection) do
    case collection.type do
      :tag -> "/tags/#{collection.name}.html"
      :category -> "/categories/#{collection.name}.html"
      :posts -> "/posts/index.html"
      _ -> "/#{collection.type}s/#{collection.name}.html"
    end
  end

  defp render_collection_with_layout(page, content, collection, config, mappings, file_system) do
    layout_path = find_collection_layout(collection, config, file_system)

    if layout_path do
      render_opts = [asset_mappings: mappings]

      case LayoutResolver.render_with_layout(page, layout_path, config, render_opts) do
        {:ok, html} -> html
        {:error, _} -> content
      end
    else
      content
    end
  end

  defp find_collection_layout(collection, config, file_system) do
    layouts_path = Map.get(config, :layouts_path, "layouts")
    site_path = Map.get(config, :site_path, ".")

    absolute_layouts_path =
      if Path.type(layouts_path) == :relative,
        do: Path.join(site_path, layouts_path),
        else: layouts_path

    layout_candidates = [
      Path.join(absolute_layouts_path, "#{collection.type}.html.heex"),
      Path.join(absolute_layouts_path, "collection.html.heex"),
      Path.join(absolute_layouts_path, "default.html.heex")
    ]

    Enum.find(layout_candidates, &file_system.exists?/1)
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
      Enum.map_join(pagination.page_numbers, " ", fn page_num ->
        url = if page_num == 1, do: "../index.html", else: "../page/#{page_num}.html"

        if page_num == pagination.current_page do
          ~s(<span class="pagination-page current">#{page_num}</span>)
        else
          ~s(<a href="#{url}" class="pagination-page">#{page_num}</a>)
        end
      end)

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
    file_system = Keyword.get(opts, :file_system, Alkali.Infrastructure.FileSystem)
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

      file_system.mkdir_p!(output_dir)

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
    FileSystem.write(path, content)
  end

  defp default_asset_writer(path, content) do
    FileSystem.write_with_path(path, content)
  end
end
