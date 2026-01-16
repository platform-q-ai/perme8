defmodule Mix.Tasks.StaticSite.Build do
  @shortdoc "Builds the static site"

  @moduledoc """
  Builds the static site from content files.

      mix static_site.build [options]

  ## Options

  - `--draft` or `-d` - Include draft posts
  - `--verbose` or `-v` - Show detailed build output
  - `--clean` or `-c` - Clean output directory before building
  - `--posts-per-page N` - Enable pagination with N posts per page (default: no pagination)

  ## Examples

      mix static_site.build
      mix static_site.build --draft
      mix static_site.build -v --draft
      mix static_site.build --clean
      mix static_site.build --posts-per-page 10
  """

  use Mix.Task

  @impl true
  def run(args) do
    {options, positional_args, _} =
      OptionParser.parse(args,
        switches: [
          draft: :boolean,
          drafts: :boolean,
          verbose: :boolean,
          clean: :boolean,
          posts_per_page: :integer
        ],
        aliases: [d: :draft, v: :verbose, c: :clean]
      )

    verbose = Keyword.get(options, :verbose, false)
    # Support both --draft and --drafts flags
    draft = Keyword.get(options, :draft, false) || Keyword.get(options, :drafts, false)
    clean = Keyword.get(options, :clean, false)
    posts_per_page = Keyword.get(options, :posts_per_page, nil)

    # Use first positional argument as site_path, default to "."
    site_path = List.first(positional_args) || "."

    # Clean output directory if --clean flag is provided
    if clean do
      # Construct the output directory path relative to site_path
      output_dir = Path.join([site_path, "_site"])

      case StaticSite.clean_output(output_dir) do
        :ok ->
          if verbose, do: Mix.shell().info("Cleaned output directory: #{output_dir}")

        {:error, reason} ->
          Mix.shell().error("Error cleaning: #{reason}")
          raise Mix.Error, message: "Failed to clean output directory: #{reason}"
      end
    end

    if verbose do
      Mix.shell().info("Building static site...")
    end

    if posts_per_page do
      Mix.shell().info("  Pagination enabled: #{posts_per_page} posts per page")
    end

    build_opts = [draft: draft, verbose: verbose]

    build_opts =
      if posts_per_page,
        do: Keyword.put(build_opts, :posts_per_page, posts_per_page),
        else: build_opts

    case StaticSite.build_site(site_path, build_opts) do
      {:ok, summary} ->
        Mix.shell().info([
          :green,
          "Build completed successfully!",
          :reset,
          "\n\nSummary:"
        ])

        Mix.shell().info("  Pages: #{summary.pages}")
        Mix.shell().info("  Collections: #{summary.collections}")
        Mix.shell().info("  Assets: #{summary.assets}")
        Mix.shell().info("  Files written: #{summary.files_written}")

        if Map.has_key?(summary, :stats) do
          stats = summary.stats
          Mix.shell().info("\nStats:")
          Mix.shell().info("  Parsed files: #{Map.get(stats, :total_pages, 0)}")
          Mix.shell().info("  Rendered pages: #{Map.get(stats, :rendered_pages, 0)}")
          Mix.shell().info("  Generated tag pages: #{Map.get(stats, :tag_pages, 0)}")
          Mix.shell().info("  Generated category pages: #{Map.get(stats, :category_pages, 0)}")
          Mix.shell().info("  Drafts found: #{Map.get(stats, :drafts, 0)}")

          # Show incremental build stats if applicable
          if Map.get(stats, :incremental, false) do
            changed = Map.get(stats, :changed, 0)
            skipped = Map.get(stats, :skipped, 0)

            Mix.shell().info(
              "\nRebuilt #{changed} file#{if changed == 1, do: "", else: "s"} (#{changed} changed, #{skipped} skipped)"
            )
          end
        end

        Mix.shell().info("\nOutput directory: _site/")

      {:error, reason} ->
        Mix.shell().error("Build failed: #{reason}")
        # Raise Mix.Error instead of System.halt for better test compatibility
        raise Mix.Error, message: "Build failed: #{reason}"
    end
  end
end
