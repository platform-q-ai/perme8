defmodule Alkali.Application.UseCases.GenerateCollectionsTest do
  use ExUnit.Case, async: true

  alias Alkali.Application.UseCases.GenerateCollections
  alias Alkali.Domain.Entities.Page

  describe "execute/2" do
    test "groups pages by tags" do
      pages = [
        %Page{title: "Post 1", tags: ["elixir", "phoenix"], draft: false},
        %Page{title: "Post 2", tags: ["elixir"], draft: false},
        %Page{title: "Post 3", tags: ["phoenix"], draft: false}
      ]

      {:ok, collections} = GenerateCollections.execute(pages)

      tag_collections = Enum.filter(collections, &(&1.type == :tag))
      elixir_collection = Enum.find(tag_collections, &(&1.name == "elixir"))
      phoenix_collection = Enum.find(tag_collections, &(&1.name == "phoenix"))

      assert length(elixir_collection.pages) == 2
      assert length(phoenix_collection.pages) == 2
    end

    test "groups pages by categories" do
      pages = [
        %Page{title: "Post 1", category: "tutorials", draft: false},
        %Page{title: "Post 2", category: "tutorials", draft: false},
        %Page{title: "Post 3", category: "news", draft: false}
      ]

      {:ok, collections} = GenerateCollections.execute(pages)

      category_collections = Enum.filter(collections, &(&1.type == :category))
      tutorials_collection = Enum.find(category_collections, &(&1.name == "tutorials"))
      news_collection = Enum.find(category_collections, &(&1.name == "news"))

      assert length(tutorials_collection.pages) == 2
      assert length(news_collection.pages) == 1
    end

    test "excludes draft posts from collections" do
      pages = [
        %Page{title: "Post 1", tags: ["elixir"], draft: true},
        %Page{title: "Post 2", tags: ["elixir"], draft: false},
        %Page{title: "Post 3", category: "news", draft: true}
      ]

      {:ok, collections} = GenerateCollections.execute(pages)

      elixir_collection = Enum.find(collections, &(&1.type == :tag && &1.name == "elixir"))
      news_collection = Enum.find(collections, &(&1.type == :category && &1.name == "news"))

      assert Enum.count(elixir_collection.pages) == 1
      assert news_collection.pages == []
    end

    test "sorts pages by date descending" do
      date1 = DateTime.from_naive!(~N[2024-01-01 00:00:00], "Etc/UTC")
      date2 = DateTime.from_naive!(~N[2024-01-02 00:00:00], "Etc/UTC")
      date3 = DateTime.from_naive!(~N[2024-01-03 00:00:00], "Etc/UTC")

      pages = [
        %Page{title: "Post 1", tags: ["test"], date: date1, draft: false},
        %Page{title: "Post 2", tags: ["test"], date: date3, draft: false},
        %Page{title: "Post 3", tags: ["test"], date: date2, draft: false}
      ]

      {:ok, collections} = GenerateCollections.execute(pages)

      test_collection = Enum.find(collections, &(&1.type == :tag && &1.name == "test"))
      [first, second, third] = test_collection.pages

      # date3
      assert first.title == "Post 2"
      # date2
      assert second.title == "Post 3"
      # date1
      assert third.title == "Post 1"
    end

    test "returns empty list when no pages provided" do
      {:ok, collections} = GenerateCollections.execute([])
      assert collections == []
    end

    test "handles pages without tags or categories" do
      pages = [
        %Page{title: "Post 1", tags: [], category: nil, draft: false}
      ]

      {:ok, collections} = GenerateCollections.execute(pages)
      assert collections == []
    end

    test "handles pages with multiple tags" do
      pages = [
        %Page{title: "Post 1", tags: ["elixir", "web", "phoenix"], draft: false}
      ]

      {:ok, collections} = GenerateCollections.execute(pages)

      elixir = Enum.find(collections, &(&1.type == :tag && &1.name == "elixir"))
      web = Enum.find(collections, &(&1.type == :tag && &1.name == "web"))
      phoenix = Enum.find(collections, &(&1.type == :tag && &1.name == "phoenix"))

      assert length(elixir.pages) == 1
      assert length(web.pages) == 1
      assert length(phoenix.pages) == 1
    end

    test "includes draft pages when include_drafts is true" do
      pages = [
        %Page{title: "Post 1", tags: ["elixir"], draft: true},
        %Page{title: "Post 2", tags: ["elixir"], draft: false}
      ]

      {:ok, collections} = GenerateCollections.execute(pages, include_drafts: true)

      elixir_collection = Enum.find(collections, &(&1.type == :tag && &1.name == "elixir"))
      assert length(elixir_collection.pages) == 2
    end
  end
end
