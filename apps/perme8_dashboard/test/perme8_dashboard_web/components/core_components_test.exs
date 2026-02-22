defmodule Perme8DashboardWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import Phoenix.Component, only: [sigil_H: 2]

  alias Perme8DashboardWeb.CoreComponents

  describe "flash/1" do
    test "renders info flash message" do
      assigns = %{flash: %{"info" => "Operation succeeded"}}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash kind={:info} flash={@flash} />
        """)

      assert html =~ "Operation succeeded"
      assert html =~ "alert-info"
      assert html =~ ~s|role="alert"|
    end

    test "renders error flash message" do
      assigns = %{flash: %{"error" => "Something went wrong"}}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash kind={:error} flash={@flash} />
        """)

      assert html =~ "Something went wrong"
      assert html =~ "alert-error"
    end

    test "does not render when no flash message present" do
      assigns = %{flash: %{}}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash kind={:info} flash={@flash} />
        """)

      refute html =~ "alert-info"
    end
  end

  describe "flash_group/1" do
    test "renders flash group container" do
      assigns = %{flash: %{"info" => "Info message"}}

      html =
        rendered_to_string(~H"""
        <CoreComponents.flash_group flash={@flash} />
        """)

      assert html =~ "Info message"
      assert html =~ ~s|aria-live="polite"|
    end
  end

  describe "button/1" do
    test "renders button with DaisyUI btn class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button>Click me</CoreComponents.button>
        """)

      assert html =~ "Click me"
      assert html =~ "btn"
    end

    test "renders button with primary variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button variant="primary">Action</CoreComponents.button>
        """)

      assert html =~ "btn-primary"
    end

    test "renders button with size class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button size="sm">Small</CoreComponents.button>
        """)

      assert html =~ "btn-sm"
    end

    test "renders as link when navigate is provided" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.button navigate="/somewhere">Go</CoreComponents.button>
        """)

      assert html =~ "href"
      assert html =~ "/somewhere"
    end
  end

  describe "icon/1" do
    test "renders heroicon span with icon name class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.icon name="hero-beaker" />
        """)

      assert html =~ "<span"
      assert html =~ "hero-beaker"
    end

    test "renders icon with custom class" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.icon name="hero-beaker" class="size-8" />
        """)

      assert html =~ "size-8"
    end
  end

  describe "header/1" do
    test "renders header with title" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.header>My Title</CoreComponents.header>
        """)

      assert html =~ "My Title"
      assert html =~ "<h1"
    end

    test "renders header with subtitle" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.header>
          Title
          <:subtitle>Some description</:subtitle>
        </CoreComponents.header>
        """)

      assert html =~ "Some description"
    end
  end

  describe "back/1" do
    test "renders back link with arrow icon" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <CoreComponents.back navigate="/">Back to home</CoreComponents.back>
        """)

      assert html =~ "Back to home"
      assert html =~ "hero-arrow-left"
      assert html =~ ~s|href="/"|
    end
  end
end
