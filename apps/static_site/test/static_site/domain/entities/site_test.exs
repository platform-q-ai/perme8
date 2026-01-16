defmodule StaticSite.Domain.Entities.SiteTest do
  use ExUnit.Case, async: true

  alias StaticSite.Domain.Entities.Site

  describe "new/1" do
    test "creates a site struct with all configuration fields" do
      attrs = %{
        title: "My Blog",
        url: "https://myblog.com",
        author: "John Doe",
        output_dir: "_site",
        post_layout: "post",
        page_layout: "page"
      }

      site = Site.new(attrs)

      assert site.title == "My Blog"
      assert site.url == "https://myblog.com"
      assert site.author == "John Doe"
      assert site.output_dir == "_site"
      assert site.post_layout == "post"
      assert site.page_layout == "page"
    end

    test "creates site with minimal fields and defaults" do
      attrs = %{
        title: "Simple Blog",
        url: "https://example.com"
      }

      site = Site.new(attrs)

      assert site.title == "Simple Blog"
      assert site.url == "https://example.com"
      assert site.author == nil
      assert site.output_dir == "_site"
      assert site.post_layout == "default"
      assert site.page_layout == "default"
    end

    test "allows custom output directory" do
      attrs = %{
        title: "Blog",
        url: "https://example.com",
        output_dir: "public"
      }

      site = Site.new(attrs)

      assert site.output_dir == "public"
    end

    test "allows custom layout defaults" do
      attrs = %{
        title: "Blog",
        url: "https://example.com",
        post_layout: "custom_post",
        page_layout: "custom_page"
      }

      site = Site.new(attrs)

      assert site.post_layout == "custom_post"
      assert site.page_layout == "custom_page"
    end
  end

  describe "validation" do
    test "validates required fields are present" do
      valid_attrs = %{
        title: "Blog",
        url: "https://example.com"
      }

      assert {:ok, _site} = Site.validate(valid_attrs)
    end

    test "fails validation when title is missing" do
      invalid_attrs = %{
        url: "https://example.com"
      }

      assert {:error, errors} = Site.validate(invalid_attrs)
      assert "title is required" in errors
    end

    test "fails validation when url is missing" do
      invalid_attrs = %{
        title: "Blog"
      }

      assert {:error, errors} = Site.validate(invalid_attrs)
      assert "url is required" in errors
    end

    test "fails validation for multiple missing fields" do
      invalid_attrs = %{}

      assert {:error, errors} = Site.validate(invalid_attrs)
      assert "title is required" in errors
      assert "url is required" in errors
    end

    test "validates URL format" do
      valid_attrs = %{
        title: "Blog",
        url: "https://example.com"
      }

      assert {:ok, _site} = Site.validate(valid_attrs)
    end

    test "fails validation for invalid URL format" do
      invalid_attrs = %{
        title: "Blog",
        url: "not-a-url"
      }

      assert {:error, errors} = Site.validate(invalid_attrs)
      assert "url must be a valid URL" in errors
    end
  end
end
