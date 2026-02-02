defmodule Mix.Tasks.Alkali.PostTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  @tmp_dir "tmp/mix_tasks_test"

  setup do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)
    on_exit(fn -> File.rm_rf!(@tmp_dir) end)
    :ok
  end

  describe "alkali.new.post" do
    test "creates post in specified site path" do
      site_path = Path.join(@tmp_dir, "my_site")
      File.mkdir_p!(Path.join(site_path, "content/posts"))

      output =
        capture_io(fn ->
          Mix.Tasks.Alkali.New.Post.run(["My Post", site_path])
        end)

      assert output =~ "Created new post"
      assert output =~ "my_site/content/posts"

      files = File.ls!(Path.join(site_path, "content/posts"))
      assert Enum.any?(files, fn f -> String.contains?(f, "my-post.md") end)
    end

    test "creates post using --path option" do
      site_path = Path.join(@tmp_dir, "option_site")
      File.mkdir_p!(Path.join(site_path, "content/posts"))

      output =
        capture_io(fn ->
          Mix.Tasks.Alkali.New.Post.run(["Option Post", "--path", site_path])
        end)

      assert output =~ "Created new post"
      assert output =~ "option_site/content/posts"

      files = File.ls!(Path.join(site_path, "content/posts"))
      assert Enum.any?(files, fn f -> String.contains?(f, "option-post.md") end)
    end
  end

  describe "alkali.post" do
    test "creates post in specified site path" do
      site_path = Path.join(@tmp_dir, "short_site")
      File.mkdir_p!(Path.join(site_path, "content/posts"))

      output =
        capture_io(fn ->
          Mix.Tasks.Alkali.Post.run(["Short Post", site_path])
        end)

      assert output =~ "Created:"
      assert output =~ "short_site/content/posts"

      files = File.ls!(Path.join(site_path, "content/posts"))
      assert Enum.any?(files, fn f -> String.contains?(f, "short-post.md") end)
    end

    test "creates post using --path option" do
      site_path = Path.join(@tmp_dir, "short_option_site")
      File.mkdir_p!(Path.join(site_path, "content/posts"))

      output =
        capture_io(fn ->
          Mix.Tasks.Alkali.Post.run(["Short Option", "--path", site_path])
        end)

      assert output =~ "Created:"
      assert output =~ "short_option_site/content/posts"

      files = File.ls!(Path.join(site_path, "content/posts"))
      assert Enum.any?(files, fn f -> String.contains?(f, "short-option.md") end)
    end
  end
end
