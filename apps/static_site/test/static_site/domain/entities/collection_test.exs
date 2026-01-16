defmodule StaticSite.Domain.Entities.CollectionTest do
  use ExUnit.Case, async: true

  alias StaticSite.Domain.Entities.{Collection, Page}

  describe "new/2" do
    test "creates a collection with name and type" do
      collection = Collection.new("elixir", :tag)

      assert collection.name == "elixir"
      assert collection.type == :tag
      assert collection.pages == []
    end

    test "creates a category collection" do
      collection = Collection.new("tutorials", :category)

      assert collection.name == "tutorials"
      assert collection.type == :category
      assert collection.pages == []
    end
  end

  describe "add_page/2" do
    test "adds a page to the collection" do
      collection = Collection.new("elixir", :tag)
      page = %Page{title: "First Post", slug: "first-post"}

      updated_collection = Collection.add_page(collection, page)

      assert length(updated_collection.pages) == 1
      assert hd(updated_collection.pages).title == "First Post"
    end

    test "adds multiple pages" do
      collection = Collection.new("elixir", :tag)
      page1 = %Page{title: "First Post", slug: "first"}
      page2 = %Page{title: "Second Post", slug: "second"}

      updated_collection =
        collection
        |> Collection.add_page(page1)
        |> Collection.add_page(page2)

      assert length(updated_collection.pages) == 2
    end
  end

  describe "sort_by_date/1" do
    test "sorts pages by date descending" do
      page1 = %Page{title: "Old Post", date: ~U[2024-01-10 10:00:00Z]}
      page2 = %Page{title: "New Post", date: ~U[2024-01-15 10:00:00Z]}
      page3 = %Page{title: "Middle Post", date: ~U[2024-01-12 10:00:00Z]}

      collection =
        Collection.new("elixir", :tag)
        |> Collection.add_page(page1)
        |> Collection.add_page(page2)
        |> Collection.add_page(page3)

      sorted_collection = Collection.sort_by_date(collection)

      assert Enum.at(sorted_collection.pages, 0).title == "New Post"
      assert Enum.at(sorted_collection.pages, 1).title == "Middle Post"
      assert Enum.at(sorted_collection.pages, 2).title == "Old Post"
    end

    test "handles pages without dates" do
      page_with_date = %Page{title: "Dated", date: ~U[2024-01-15 10:00:00Z]}
      page_without_date = %Page{title: "Undated", date: nil}

      collection =
        Collection.new("elixir", :tag)
        |> Collection.add_page(page_without_date)
        |> Collection.add_page(page_with_date)

      sorted_collection = Collection.sort_by_date(collection)

      # Pages with dates come first, then pages without dates
      assert Enum.at(sorted_collection.pages, 0).title == "Dated"
      assert Enum.at(sorted_collection.pages, 1).title == "Undated"
    end
  end
end
