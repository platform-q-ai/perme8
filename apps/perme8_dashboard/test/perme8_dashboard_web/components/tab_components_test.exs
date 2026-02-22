defmodule Perme8DashboardWeb.TabComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest
  import Phoenix.Component, only: [sigil_H: 2]

  alias Perme8DashboardWeb.TabComponents

  defp render_tab_bar(tabs, active_tab) do
    assigns = %{tabs: tabs, active_tab: active_tab}

    rendered =
      rendered_to_string(~H"""
      <TabComponents.tab_bar tabs={@tabs} active_tab={@active_tab} />
      """)

    rendered
  end

  describe "tab_bar/1" do
    test "renders tab bar with data-tab attributes" do
      html = render_tab_bar([{:features, "Features", "/"}], :features)

      assert html =~ ~s|data-tab="features"|
      assert html =~ ~s|role="tablist"|
    end

    test "renders tab labels" do
      html = render_tab_bar([{:features, "Features", "/"}], :features)

      assert html =~ "Features"
    end

    test "active tab has tab-active class" do
      html = render_tab_bar([{:features, "Features", "/"}], :features)

      # The features tab should have tab-active class and data-tab attribute
      assert html =~ ~r/class="[^"]*tab-active[^"]*"[^>]*data-tab="features"/s
    end

    test "inactive tab does not have tab-active class" do
      html =
        render_tab_bar(
          [{:features, "Features", "/"}, {:sessions, "Sessions", "/sessions"}],
          :features
        )

      # The sessions tab should NOT have tab-active
      refute html =~ ~r/class="[^"]*tab-active[^"]*"[^>]*data-tab="sessions"/s
    end

    test "tabs render as navigation links with correct paths" do
      html =
        render_tab_bar(
          [{:features, "Features", "/"}, {:sessions, "Sessions", "/sessions"}],
          :features
        )

      assert html =~ ~s|href="/"|
      assert html =~ ~s|href="/sessions"|
    end

    test "renders multiple tabs" do
      html =
        render_tab_bar(
          [{:features, "Features", "/"}, {:sessions, "Sessions", "/sessions"}],
          :features
        )

      assert html =~ ~s|data-tab="features"|
      assert html =~ ~s|data-tab="sessions"|
    end

    test "renders with DaisyUI tab classes" do
      html = render_tab_bar([{:features, "Features", "/"}], :features)

      assert html =~ "tabs"
      assert html =~ "tabs-bordered"
      assert html =~ "tab"
    end

    test "each tab link has role='tab'" do
      html = render_tab_bar([{:features, "Features", "/"}], :features)

      assert html =~ ~s|role="tab"|
    end
  end
end
