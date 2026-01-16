defmodule StaticSite.Application.UseCases.CreateNewPostTest do
  use ExUnit.Case, async: true

  alias StaticSite.Application.UseCases.CreateNewPost

  describe "execute/2" do
    test "creates a new post file with frontmatter template" do
      title = "Getting Started with Elixir"

      file_writer = fn path, content ->
        send(self(), {:write_file, path, content})
        {:ok, path}
      end

      file_checker = fn _path -> false end

      result =
        CreateNewPost.execute(title,
          site_path: "/tmp/blog",
          file_writer: file_writer,
          file_checker: file_checker
        )

      assert {:ok, %{file_path: file_path}} = result
      assert String.contains?(file_path, "getting-started-with-elixir.md")

      assert_received {:write_file, ^file_path, content}
      assert content =~ "---"
      assert content =~ "title: \"Getting Started with Elixir\""
      assert content =~ "draft: true"
      assert content =~ "layout: post"
    end

    test "generates unique filename if file already exists" do
      title = "My Post"

      file_checker = fn path ->
        String.contains?(path, "my-post.md") and not String.contains?(path, "my-post-2.md")
      end

      file_writer = fn path, _content ->
        {:ok, path}
      end

      result =
        CreateNewPost.execute(title,
          site_path: "/tmp/blog",
          file_writer: file_writer,
          file_checker: file_checker
        )

      assert {:ok, %{file_path: file_path}} = result
      assert String.contains?(file_path, "my-post-2.md")
    end

    test "includes current date in filename" do
      title = "Test Post"

      file_writer = fn path, _content ->
        send(self(), {:path, path})
        {:ok, path}
      end

      CreateNewPost.execute(title,
        file_writer: file_writer,
        file_checker: fn _ -> false end
      )

      today = Date.utc_today() |> Date.to_iso8601()
      assert_received {:path, path}
      assert String.contains?(path, today)
    end

    test "uses custom date if provided" do
      title = "Old Post"
      custom_date = ~D[2023-01-15]

      file_writer = fn path, _content ->
        send(self(), {:path, path})
        {:ok, path}
      end

      CreateNewPost.execute(title,
        date: custom_date,
        file_writer: file_writer,
        file_checker: fn _ -> false end
      )

      assert_received {:path, path}
      assert String.contains?(path, "2023-01-15")
    end

    test "writes to content/posts by default" do
      title = "Test"

      file_writer = fn path, _content ->
        send(self(), {:path, path})
        {:ok, path}
      end

      CreateNewPost.execute(title,
        file_writer: file_writer,
        file_checker: fn _ -> false end
      )

      assert_received {:path, path}
      assert String.contains?(path, "content/posts")
    end
  end
end
