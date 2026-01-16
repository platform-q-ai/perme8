defmodule StaticSite.Infrastructure.Renderers.TemplateRendererTest do
  use ExUnit.Case, async: true

  alias StaticSite.Infrastructure.Renderers.TemplateRenderer

  describe "render/3" do
    test "renders template with assigns" do
      template = "<h1><%= @page.title %></h1>"
      assigns = %{page: %{title: "Hello World"}}
      result = TemplateRenderer.render(template, assigns)
      assert result == "<h1>Hello World</h1>"
    end

    test "renders template with site config" do
      template = "<%= @site.name %>"
      assigns = %{site: %{name: "My Blog"}}
      result = TemplateRenderer.render(template, assigns)
      assert result == "My Blog"
    end

    test "supports conditionals in template" do
      template = "<%= if @page.draft do %>Draft<% else %>Published<% end %>"
      assigns = %{page: %{draft: true}}
      result = TemplateRenderer.render(template, assigns)
      assert result =~ "Draft"
    end

    test "supports loops in template" do
      template = "<%= for tag <- @tags do %><span><%= tag %></span><% end %>"
      assigns = %{tags: ["elixir", "phoenix"]}
      result = TemplateRenderer.render(template, assigns)
      assert result =~ "<span>elixir</span>"
      assert result =~ "<span>phoenix</span>"
    end

    test "handles complex data structures" do
      template = "<%= @page.title %> by <%= @site.author %>"
      assigns = %{page: %{title: "First Post"}, site: %{author: "John"}}
      result = TemplateRenderer.render(template, assigns)
      assert result == "First Post by John"
    end
  end
end
