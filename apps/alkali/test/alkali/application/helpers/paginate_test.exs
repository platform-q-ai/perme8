defmodule Alkali.Application.Helpers.PaginateTest do
  use ExUnit.Case, async: true

  alias Alkali.Application.Helpers.Paginate

  describe "paginate/2" do
    test "splits items into pages with default per_page (10)" do
      items = Enum.to_list(1..25)
      pages = Paginate.paginate(items)

      assert length(pages) == 3
      assert Enum.at(pages, 0).items == Enum.to_list(1..10)
      assert Enum.at(pages, 1).items == Enum.to_list(11..20)
      assert Enum.at(pages, 2).items == Enum.to_list(21..25)
    end

    test "respects custom per_page option" do
      items = Enum.to_list(1..15)
      pages = Paginate.paginate(items, per_page: 5)

      assert length(pages) == 3
      assert Enum.at(pages, 0).items == [1, 2, 3, 4, 5]
      assert Enum.at(pages, 1).items == [6, 7, 8, 9, 10]
      assert Enum.at(pages, 2).items == [11, 12, 13, 14, 15]
    end

    test "handles items count exactly matching per_page" do
      items = Enum.to_list(1..10)
      pages = Paginate.paginate(items, per_page: 10)

      assert length(pages) == 1
      assert hd(pages).items == items
    end

    test "handles fewer items than per_page" do
      items = [1, 2, 3]
      pages = Paginate.paginate(items, per_page: 10)

      assert length(pages) == 1
      assert hd(pages).items == [1, 2, 3]
    end

    test "handles empty list" do
      pages = Paginate.paginate([], per_page: 10)

      # Empty list produces no pages (not even page 1)
      assert length(pages) == 0
    end

    test "assigns correct page numbers" do
      items = Enum.to_list(1..25)
      pages = Paginate.paginate(items, per_page: 10)

      assert Enum.at(pages, 0).page_number == 1
      assert Enum.at(pages, 1).page_number == 2
      assert Enum.at(pages, 2).page_number == 3
    end

    test "includes pagination metadata for each page" do
      items = Enum.to_list(1..25)
      pages = Paginate.paginate(items, per_page: 10)

      page1 = Enum.at(pages, 0)
      assert page1.pagination.current_page == 1
      assert page1.pagination.total_pages == 3
      assert page1.pagination.per_page == 10
      assert page1.pagination.total_items == 25
      assert page1.pagination.has_prev == false
      assert page1.pagination.has_next == true

      page2 = Enum.at(pages, 1)
      assert page2.pagination.current_page == 2
      assert page2.pagination.has_prev == true
      assert page2.pagination.has_next == true

      page3 = Enum.at(pages, 2)
      assert page3.pagination.current_page == 3
      assert page3.pagination.has_prev == true
      assert page3.pagination.has_next == false
    end

    test "uses custom url_template for pagination links" do
      items = Enum.to_list(1..25)
      pages = Paginate.paginate(items, per_page: 10, url_template: "/posts/page/:page")

      page1 = Enum.at(pages, 0)
      assert page1.pagination.prev_url == nil
      assert page1.pagination.next_url == "/posts/page/2"

      page2 = Enum.at(pages, 1)
      # Page 1 is index, so no /page/1
      assert page2.pagination.prev_url == nil
      assert page2.pagination.next_url == "/posts/page/3"

      page3 = Enum.at(pages, 2)
      assert page3.pagination.prev_url == "/posts/page/2"
      assert page3.pagination.next_url == nil
    end

    test "includes page_numbers in pagination metadata" do
      items = Enum.to_list(1..35)
      pages = Paginate.paginate(items, per_page: 10)

      page1 = Enum.at(pages, 0)
      assert page1.pagination.page_numbers == [1, 2, 3, 4]
    end
  end

  describe "calculate_total_pages/2" do
    test "calculates correct number of pages" do
      assert Paginate.calculate_total_pages(100, 10) == 10
      assert Paginate.calculate_total_pages(95, 10) == 10
      assert Paginate.calculate_total_pages(91, 10) == 10
      assert Paginate.calculate_total_pages(90, 10) == 9
      assert Paginate.calculate_total_pages(1, 10) == 1
    end

    test "handles edge cases" do
      assert Paginate.calculate_total_pages(0, 10) == 1
      assert Paginate.calculate_total_pages(1, 1) == 1
      assert Paginate.calculate_total_pages(10, 10) == 1
      assert Paginate.calculate_total_pages(11, 10) == 2
    end
  end

  describe "build_pagination_meta/5" do
    test "builds correct metadata for first page" do
      meta = Paginate.build_pagination_meta(1, 5, 10, 47, "/posts/page/:page")

      assert meta.current_page == 1
      assert meta.total_pages == 5
      assert meta.per_page == 10
      assert meta.total_items == 47
      assert meta.has_prev == false
      assert meta.has_next == true
      assert meta.prev_url == nil
      assert meta.next_url == "/posts/page/2"
      assert meta.page_numbers == [1, 2, 3, 4, 5]
    end

    test "builds correct metadata for middle page" do
      meta = Paginate.build_pagination_meta(3, 5, 10, 47, "/posts/page/:page")

      assert meta.current_page == 3
      assert meta.has_prev == true
      assert meta.has_next == true
      assert meta.prev_url == "/posts/page/2"
      assert meta.next_url == "/posts/page/4"
    end

    test "builds correct metadata for last page" do
      meta = Paginate.build_pagination_meta(5, 5, 10, 47, "/posts/page/:page")

      assert meta.current_page == 5
      assert meta.has_prev == true
      assert meta.has_next == false
      assert meta.prev_url == "/posts/page/4"
      assert meta.next_url == nil
    end

    test "handles single page" do
      meta = Paginate.build_pagination_meta(1, 1, 10, 5, "/posts/page/:page")

      assert meta.current_page == 1
      assert meta.total_pages == 1
      assert meta.has_prev == false
      assert meta.has_next == false
      assert meta.prev_url == nil
      assert meta.next_url == nil
      assert meta.page_numbers == [1]
    end
  end

  describe "build_page_url/3" do
    test "returns nil for page 1 (index page)" do
      assert Paginate.build_page_url(1, "/posts/page/:page") == nil
      assert Paginate.build_page_url(1, "/categories/elixir/page/:page") == nil
    end

    test "replaces :page placeholder for pages 2+" do
      assert Paginate.build_page_url(2, "/posts/page/:page") == "/posts/page/2"
      assert Paginate.build_page_url(5, "/posts/page/:page") == "/posts/page/5"
      assert Paginate.build_page_url(10, "/posts/page/:page") == "/posts/page/10"
    end

    test "supports custom placeholders via replacements" do
      assert Paginate.build_page_url(2, "/categories/:category/page/:page", category: "elixir") ==
               "/categories/elixir/page/2"

      assert Paginate.build_page_url(3, "/tags/:tag/page/:page", tag: "phoenix") ==
               "/tags/phoenix/page/3"
    end

    test "handles multiple custom placeholders" do
      assert Paginate.build_page_url(2, "/:year/:month/page/:page", year: 2024, month: "01") ==
               "/2024/01/page/2"
    end
  end

  describe "page_file_path/2" do
    test "returns index.html for page 1" do
      assert Paginate.page_file_path("/posts", 1) == "/posts/index.html"
      assert Paginate.page_file_path("/categories/elixir", 1) == "/categories/elixir/index.html"
    end

    test "returns page/N.html for pages 2+" do
      assert Paginate.page_file_path("/posts", 2) == "/posts/page/2.html"
      assert Paginate.page_file_path("/posts", 3) == "/posts/page/3.html"
      assert Paginate.page_file_path("/posts", 10) == "/posts/page/10.html"
    end

    test "handles nested base paths" do
      assert Paginate.page_file_path("/categories/elixir", 2) ==
               "/categories/elixir/page/2.html"

      assert Paginate.page_file_path("/tags/web", 5) == "/tags/web/page/5.html"
    end
  end
end
