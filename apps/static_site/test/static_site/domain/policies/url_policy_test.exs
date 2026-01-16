defmodule StaticSite.Domain.Policies.UrlPolicyTest do
  use ExUnit.Case, async: true

  alias StaticSite.Domain.Policies.UrlPolicy

  describe "generate_url/2" do
    test "generates URL from file path" do
      assert UrlPolicy.generate_url("content/posts/my-post.md", "content") ==
               "/posts/my-post.html"
    end

    test "preserves folder hierarchy" do
      assert UrlPolicy.generate_url("content/posts/2024/01/my-post.md", "content") ==
               "/posts/2024/01/my-post.html"
    end

    test "handles nested paths" do
      assert UrlPolicy.generate_url("content/docs/guides/getting-started.md", "content") ==
               "/docs/guides/getting-started.html"
    end

    test "adds .html extension" do
      assert UrlPolicy.generate_url("content/about.md", "content") == "/about.html"
    end

    test "handles pages in root content directory" do
      assert UrlPolicy.generate_url("content/index.md", "content") == "/index.html"
    end

    test "removes content prefix from URL" do
      assert UrlPolicy.generate_url("content/posts/test.md", "content") == "/posts/test.html"
    end

    test "works with different content directory names" do
      assert UrlPolicy.generate_url("src/blog/post.md", "src") == "/blog/post.html"
    end
  end
end
