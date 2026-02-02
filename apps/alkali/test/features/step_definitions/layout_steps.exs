defmodule Alkali.LayoutSteps do
  use Cucumber.StepDefinition
  use ExUnit.Case

  # --- GIVEN Steps ---

  step "a layout exists at {string}", %{args: [layout_path]} = context do
    site_path = context[:site_path]
    full_path = Path.join(site_path, layout_path)

    # Create a basic HEEx layout template
    layout_content = """
    <!DOCTYPE html>
    <html>
    <head>
      <title><%= @page.title %></title>
    </head>
    <body>
      <%= @content %>
    </body>
    </html>
    """

    File.mkdir_p!(Path.dirname(full_path))
    File.write!(full_path, layout_content)

    {:ok, context |> Map.put(:last_layout_path, full_path)}
  end

  step "the config specifies:", context do
    site_path = context[:site_path]
    config_path = Path.join(site_path, "config/alkali.exs")

    # Get config content from docstring
    config_spec = context.docstring

    # Create config with the specified defaults
    config_content = """
    import Config

    config :alkali,
      site: %{
        title: "Test Site",
        url: "https://example.com"
      },
      #{config_spec}
    """

    File.write!(config_path, config_content)

    {:ok, context}
  end

  step "a post exists at {string} without layout specified",
       %{args: [file_path]} = context do
    site_path = context[:site_path]
    full_path = Path.join(site_path, file_path)

    # Create post without layout field in frontmatter
    content = """
    ---
    title: "Test Post"
    ---

    Post content.
    """

    File.mkdir_p!(Path.dirname(full_path))
    File.write!(full_path, content)

    {:ok, context |> Map.put(:last_created_file, full_path)}
  end

  step "a layout exists at {string} containing:", %{args: [layout_path]} = context do
    site_path = context[:site_path]
    full_path = Path.join(site_path, layout_path)

    # Get layout content from docstring
    layout_content = context.docstring

    File.mkdir_p!(Path.dirname(full_path))
    File.write!(full_path, layout_content)

    {:ok, context |> Map.put(:last_layout_path, full_path)}
  end

  step "a partial exists at {string}", %{args: [partial_path]} = context do
    site_path = context[:site_path]
    full_path = Path.join(site_path, partial_path)

    # Create a simple partial
    partial_content = """
    <header>
      <h1>Site Header</h1>
    </header>
    """

    File.mkdir_p!(Path.dirname(full_path))
    File.write!(full_path, partial_content)

    {:ok, context |> Map.put(:last_partial_path, full_path)}
  end

  # --- THEN Steps ---

  step "the rendered HTML should include content from the partial", context do
    site_path = context[:site_path]

    # Check that rendered HTML includes partial content
    output_path = Path.join([site_path, "_site/posts/test-post.html"])

    if File.exists?(output_path) do
      html_content = File.read!(output_path)

      assert html_content =~ "Site Header",
             "Expected rendered HTML to include content from partial"
    else
      # File doesn't exist
      assert false,
             "Expected output file to exist at #{output_path}"
    end

    {:ok, context}
  end
end
