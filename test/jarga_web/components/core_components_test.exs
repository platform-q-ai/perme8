defmodule JargaWeb.CoreComponentsTest do
  use JargaWeb.ConnCase, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import JargaWeb.CoreComponents

  describe "button/1" do
    test "renders a basic button with default variant" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button>Click me</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-soft"
      assert html =~ "btn-primary"
      assert html =~ "Click me"
    end

    test "renders primary variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="primary">Primary</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-primary"
      refute html =~ "btn-soft"
    end

    test "renders secondary variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="secondary">Secondary</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-secondary"
    end

    test "renders accent variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="accent">Accent</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-accent"
    end

    test "renders neutral variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="neutral">Neutral</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-neutral"
    end

    test "renders info variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="info">Info</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-info"
    end

    test "renders success variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="success">Success</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-success"
    end

    test "renders warning variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="warning">Warning</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-warning"
    end

    test "renders error variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="error">Error</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-error"
    end

    test "renders ghost variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="ghost">Ghost</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-ghost"
    end

    test "renders link variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="link">Link</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-link"
    end

    test "renders outline variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="outline">Outline</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-outline"
    end

    test "renders outline-primary variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="outline-primary">Outline Primary</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-outline"
      assert html =~ "btn-primary"
    end

    test "renders outline-error variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="outline-error">Outline Error</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-outline"
      assert html =~ "btn-error"
    end

    test "renders soft variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="soft">Soft</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-soft"
    end

    test "renders soft-primary variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="soft-primary">Soft Primary</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-soft"
      assert html =~ "btn-primary"
    end

    test "renders soft-error variant button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="soft-error">Soft Error</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-soft"
      assert html =~ "btn-error"
    end

    test "renders extra small size button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button size="xs">Extra Small</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-xs"
    end

    test "renders small size button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button size="sm">Small</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-sm"
    end

    test "renders medium size button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button size="md">Medium</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-md"
    end

    test "renders large size button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button size="lg">Large</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-lg"
    end

    test "renders extra large size button" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button size="xl">Extra Large</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-xl"
    end

    test "renders button with custom classes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button class="w-full mt-4">Custom Classes</.button>
        """)

      assert html =~ "btn"
      assert html =~ "w-full"
      assert html =~ "mt-4"
    end

    test "renders button with combined variant and size" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button variant="primary" size="lg">Large Primary</.button>
        """)

      assert html =~ "btn"
      assert html =~ "btn-primary"
      assert html =~ "btn-lg"
    end

    test "renders button with phx-click attribute" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button phx-click="click_event">Click Event</.button>
        """)

      assert html =~ ~s(phx-click="click_event")
      assert html =~ "Click Event"
    end

    test "renders button with disabled attribute" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button disabled>Disabled</.button>
        """)

      assert html =~ "disabled"
      assert html =~ "Disabled"
    end

    test "renders button with name and value attributes" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button name="action" value="submit">Submit Form</.button>
        """)

      assert html =~ ~s(name="action")
      assert html =~ ~s(value="submit")
    end

    test "renders link button with navigate attribute" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button navigate="/users/settings">Settings</.button>
        """)

      assert html =~ "<a"
      assert html =~ ~s(href="/users/settings")
      assert html =~ "Settings"
      refute html =~ "<button"
    end

    test "renders link button with patch attribute" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button patch="/users/edit">Edit</.button>
        """)

      assert html =~ "<a"
      assert html =~ ~s(data-phx-link="patch")
      assert html =~ ~s(href="/users/edit")
      refute html =~ "<button"
    end

    test "renders link button with href attribute" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button href="https://example.com">External Link</.button>
        """)

      assert html =~ "<a"
      assert html =~ ~s(href="https://example.com")
      refute html =~ "<button"
    end

    test "renders button element when no navigation attributes present" do
      assigns = %{}

      html =
        rendered_to_string(~H"""
        <.button>Regular Button</.button>
        """)

      assert html =~ "<button"
      assert html =~ "Regular Button"
      refute html =~ "<a"
    end
  end
end
