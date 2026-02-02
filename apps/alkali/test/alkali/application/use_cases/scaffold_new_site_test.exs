defmodule Alkali.Application.UseCases.ScaffoldNewSiteTest do
  use ExUnit.Case, async: true

  alias Alkali.Application.UseCases.ScaffoldNewSite

  describe "execute/2" do
    test "creates site directory structure and files" do
      site_name = "my_blog"

      dir_creator = fn path ->
        send(self(), {:create_dir, path})
        {:ok, path}
      end

      file_writer = fn path, _content ->
        send(self(), {:write_file, path})
        {:ok, path}
      end

      result =
        ScaffoldNewSite.execute(site_name,
          target_path: "/tmp",
          dir_creator: dir_creator,
          file_writer: file_writer
        )

      assert {:ok, summary} = result
      assert is_list(summary.created_dirs)
      assert is_list(summary.created_files)

      # Verify directories created
      assert_received {:create_dir, "/tmp/my_blog/config"}
      assert_received {:create_dir, "/tmp/my_blog/content/posts"}
      assert_received {:create_dir, "/tmp/my_blog/content/pages"}
      assert_received {:create_dir, "/tmp/my_blog/layouts/partials"}
      assert_received {:create_dir, "/tmp/my_blog/static/css"}
      assert_received {:create_dir, "/tmp/my_blog/static/js"}
      assert_received {:create_dir, "/tmp/my_blog/static/images"}

      # Verify files created
      assert_received {:write_file, config_path}
      assert String.contains?(config_path, "alkali.exs")

      # Check for example content files (13 files total with footer partial)
      files =
        Enum.reduce(1..13, [], fn _, acc ->
          receive do
            {:write_file, path} -> [path | acc]
          after
            0 -> acc
          end
        end)

      file_names = Enum.join(files, " ")
      assert String.contains?(file_names, "index.md")
      assert String.contains?(file_names, "welcome.md")
      assert String.contains?(file_names, "about.md")
      assert String.contains?(file_names, "default.html.heex")
      assert String.contains?(file_names, "home.html.heex")
      assert String.contains?(file_names, "post.html.heex")
      assert String.contains?(file_names, "page.html.heex")
      assert String.contains?(file_names, "app.css")
      assert String.contains?(file_names, "app.js")
    end

    test "fails if target directory already exists" do
      site_name = "existing_blog"

      dir_creator = fn _path ->
        {:error, :eexist}
      end

      result =
        ScaffoldNewSite.execute(site_name,
          target_path: "/tmp",
          dir_creator: dir_creator,
          file_writer: fn _, _ -> {:ok, ""} end
        )

      assert {:error, message} = result
      assert message =~ "already exists"
    end

    test "uses current directory as default target path" do
      site_name = "blog"

      dir_creator = fn path ->
        send(self(), {:path, path})
        {:ok, path}
      end

      ScaffoldNewSite.execute(site_name,
        dir_creator: dir_creator,
        file_writer: fn _, _ -> {:ok, ""} end
      )

      assert_received {:path, path}
      assert String.contains?(path, "blog/config")
    end

    test "generates valid frontmatter in example post" do
      site_name = "blog"

      file_writer = fn path, content ->
        if String.contains?(path, "welcome.md") do
          send(self(), {:welcome_content, content})
        end

        {:ok, path}
      end

      ScaffoldNewSite.execute(site_name,
        dir_creator: fn _ -> {:ok, ""} end,
        file_writer: file_writer
      )

      assert_received {:welcome_content, content}
      assert content =~ "---"
      assert content =~ "title:"
      assert content =~ "date:"
      assert content =~ "draft: false"
    end

    test "generates valid site configuration" do
      site_name = "my_site"

      file_writer = fn path, content ->
        if String.contains?(path, "alkali.exs") do
          send(self(), {:config_content, content})
        end

        {:ok, path}
      end

      ScaffoldNewSite.execute(site_name,
        dir_creator: fn _ -> {:ok, ""} end,
        file_writer: file_writer
      )

      assert_received {:config_content, content}
      assert content =~ "import Config"
      assert content =~ ":alkali"
      assert content =~ "title:"
    end

    test "returns summary with counts" do
      result =
        ScaffoldNewSite.execute("blog",
          dir_creator: fn _ -> {:ok, ""} end,
          file_writer: fn _, _ -> {:ok, ""} end
        )

      assert {:ok, summary} = result
      assert length(summary.created_dirs) >= 7
      assert length(summary.created_files) >= 10
    end
  end
end
