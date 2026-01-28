defmodule Mix.Tasks.Alkali.Build do
  @shortdoc "Builds the static site"

  @moduledoc """
  Builds the static site from content files.

      mix alkali.build [options]

  ## Options

  - `--draft` or `-d` - Include draft posts
  - `--verbose` or `-v` - Show detailed build output
  - `--clean` or `-c` - Clean output directory before building
  - `--posts-per-page N` - Enable pagination with N posts per page (default: no pagination)

  ## Examples

      mix alkali.build
      mix alkali.build --draft
      mix alkali.build -v --draft
      mix alkali.build --clean
      mix alkali.build --posts-per-page 10
  """

  use Mix.Task

  @impl true
  def run(args) do
    {options, positional_args, _} = parse_args(args)
    opts = extract_options(options)
    site_path = List.first(positional_args) || "."

    maybe_clean(site_path, opts.clean, opts.verbose)
    log_build_start(opts)

    build_opts = build_options(opts)

    case Alkali.build_site(site_path, build_opts) do
      {:ok, summary} -> print_success(summary)
      {:error, reason} -> handle_error(reason)
    end
  end

  defp parse_args(args) do
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
  end

  defp extract_options(options) do
    %{
      verbose: Keyword.get(options, :verbose, false),
      draft: Keyword.get(options, :draft, false) || Keyword.get(options, :drafts, false),
      clean: Keyword.get(options, :clean, false),
      posts_per_page: Keyword.get(options, :posts_per_page, nil)
    }
  end

  defp maybe_clean(site_path, true, verbose) do
    output_dir = Path.join([site_path, "_site"])

    case Alkali.clean_output(output_dir) do
      :ok ->
        if verbose, do: Mix.shell().info("Cleaned output directory: #{output_dir}")

      {:error, reason} ->
        Mix.shell().error("Error cleaning: #{reason}")
        raise Mix.Error, message: "Failed to clean output directory: #{reason}"
    end
  end

  defp maybe_clean(_site_path, false, _verbose), do: :ok

  defp log_build_start(%{verbose: true, posts_per_page: ppp}) do
    Mix.shell().info("Building static site...")
    if ppp, do: Mix.shell().info("  Pagination enabled: #{ppp} posts per page")
  end

  defp log_build_start(%{verbose: false, posts_per_page: ppp}) do
    if ppp, do: Mix.shell().info("  Pagination enabled: #{ppp} posts per page")
  end

  defp build_options(%{draft: draft, verbose: verbose, posts_per_page: ppp}) do
    opts = [draft: draft, verbose: verbose]
    if ppp, do: Keyword.put(opts, :posts_per_page, ppp), else: opts
  end

  defp print_success(summary) do
    Mix.shell().info([:green, "Build completed successfully!", :reset, "\n\nSummary:"])
    Mix.shell().info("  Pages: #{summary.pages}")
    Mix.shell().info("  Collections: #{summary.collections}")
    Mix.shell().info("  Assets: #{summary.assets}")
    Mix.shell().info("  Files written: #{summary.files_written}")

    if Map.has_key?(summary, :stats) do
      print_stats(summary.stats)
    end

    Mix.shell().info("\nOutput directory: _site/")
  end

  defp print_stats(stats) do
    Mix.shell().info("\nStats:")
    Mix.shell().info("  Parsed files: #{Map.get(stats, :total_pages, 0)}")
    Mix.shell().info("  Rendered pages: #{Map.get(stats, :rendered_pages, 0)}")
    Mix.shell().info("  Generated tag pages: #{Map.get(stats, :tag_pages, 0)}")
    Mix.shell().info("  Generated category pages: #{Map.get(stats, :category_pages, 0)}")
    Mix.shell().info("  Drafts found: #{Map.get(stats, :drafts, 0)}")

    if Map.get(stats, :incremental, false) do
      print_incremental_stats(stats)
    end
  end

  defp print_incremental_stats(stats) do
    changed = Map.get(stats, :changed, 0)
    skipped = Map.get(stats, :skipped, 0)
    suffix = if changed == 1, do: "", else: "s"

    Mix.shell().info(
      "\nRebuilt #{changed} file#{suffix} (#{changed} changed, #{skipped} skipped)"
    )
  end

  defp handle_error(reason) do
    Mix.shell().error("Build failed: #{reason}")
    raise Mix.Error, message: "Build failed: #{reason}"
  end
end
