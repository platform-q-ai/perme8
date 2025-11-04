defmodule JargaWeb.AppLive.DashboardTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Jarga.AccountsFixtures

  describe "dashboard page" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/app")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log-in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "dashboard page (authenticated)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders dashboard page for authenticated user", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app")

      assert html =~ "Welcome to Jarga"
      assert html =~ "Your authenticated dashboard"
    end

    test "displays sidebar with navigation links", %{conn: conn, user: user} do
      {:ok, _lv, html} = live(conn, ~p"/app")

      # Sidebar should contain user info
      assert html =~ user.email
      assert html =~ user.first_name
      assert html =~ user.last_name

      # Sidebar navigation links
      assert html =~ "Home"
      assert html =~ "Settings"
      assert html =~ "Log out"

      # Theme switcher label
      assert html =~ "Theme"
    end

    test "displays quick links to editor and settings", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app")

      assert html =~ "Editor"
      assert html =~ "Create and edit documents with real-time collaboration"
      assert html =~ "Settings"
      assert html =~ "Manage your account email address and password settings"
    end

    test "displays quick action buttons", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/app")

      assert html =~ "New Document"
      assert html =~ "Browse Documents"
    end

    test "navigates to new editor when clicking new document button", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app")

      # Click the "New Document" button
      assert {:error, {:live_redirect, %{to: redirect_path}}} =
               lv |> element("button", "New Document") |> render_click()

      # Should redirect to /app/editor/{uuid}
      assert redirect_path =~
               ~r|^/app/editor/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$|

      # Follow redirect and verify editor loads
      {:ok, editor_lv, html} = live(conn, redirect_path)
      assert html =~ "Collaborative Markdown Editor"
      assert has_element?(editor_lv, "#editor-container")
    end

    test "sidebar has working navigation links", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/app")

      # Test home link exists
      assert lv |> element("a[href='/app']") |> has_element?()

      # Test settings link exists
      assert lv |> element("a[href='/users/settings']") |> has_element?()

      # Test logout link exists
      assert lv |> element("a[href='/users/log-out']") |> has_element?()
    end
  end
end
