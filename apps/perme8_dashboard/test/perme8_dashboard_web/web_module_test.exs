defmodule Perme8DashboardWeb.WebModuleTest do
  use ExUnit.Case, async: true

  describe "Perme8DashboardWeb" do
    test "defines __using__/1 macro for dispatch" do
      # The __using__/1 macro dispatches to the appropriate function
      assert {:__using__, 1} in Perme8DashboardWeb.__info__(:macros)
    end

    test "defines :router dispatch that provides Phoenix.Router" do
      # Verify the router function returns a quoted block
      ast = Perme8DashboardWeb.router()
      assert is_tuple(ast)
    end

    test "defines :live_view dispatch that provides Phoenix.LiveView" do
      ast = Perme8DashboardWeb.live_view()
      assert is_tuple(ast)
    end

    test "defines :html dispatch that provides Phoenix.Component" do
      ast = Perme8DashboardWeb.html()
      assert is_tuple(ast)
    end

    test "defines verified_routes function" do
      ast = Perme8DashboardWeb.verified_routes()
      assert is_tuple(ast)
    end
  end
end
