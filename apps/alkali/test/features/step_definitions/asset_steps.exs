defmodule Alkali.AssetSteps do
  use Cucumber.StepDefinition
  use ExUnit.Case

  # --- GIVEN Steps ---

  step "a CSS file exists at {string}", %{args: [css_path]} = context do
    site_path = context[:site_path]
    full_path = Path.join(site_path, css_path)

    # Create a default CSS file
    css_content = """
    body {
      margin: 0;
      padding: 0;
    }
    """

    File.mkdir_p!(Path.dirname(full_path))
    File.write!(full_path, css_content)

    {:ok,
     context
     |> Map.put(:original_css_path, full_path)
     |> Map.put(:original_css_content, css_content)
     |> Map.put(:original_css_size, byte_size(css_content))}
  end

  step "a CSS file exists at {string} with content:", %{args: [css_path]} = context do
    site_path = context[:site_path]
    full_path = Path.join(site_path, css_path)

    # Get CSS content from docstring
    css_content = context.docstring

    File.mkdir_p!(Path.dirname(full_path))
    File.write!(full_path, css_content)

    {:ok,
     context
     |> Map.put(:original_css_path, full_path)
     |> Map.put(:original_css_content, css_content)
     |> Map.put(:original_css_size, byte_size(css_content))}
  end

  step "a JS file exists at {string} with content:", %{args: [js_path]} = context do
    site_path = context[:site_path]
    full_path = Path.join(site_path, js_path)

    # Get JS content from docstring
    js_content = context.docstring

    File.mkdir_p!(Path.dirname(full_path))
    File.write!(full_path, js_content)

    {:ok,
     context
     |> Map.put(:original_js_path, full_path)
     |> Map.put(:original_js_content, js_content)
     |> Map.put(:original_js_size, byte_size(js_content))}
  end

  step "a layout exists referencing {string}", %{args: [css_ref]} = context do
    site_path = context[:site_path]
    layout_path = Path.join(site_path, "layouts/default.html.heex")

    # Create layout that references the CSS file
    layout_content = """
    <!DOCTYPE html>
    <html>
    <head>
      <link rel="stylesheet" href="#{css_ref}">
    </head>
    <body>
      <%= @content %>
    </body>
    </html>
    """

    File.mkdir_p!(Path.dirname(layout_path))
    File.write!(layout_path, layout_content)

    # Also create a test page that will use this layout
    content_path = Path.join(site_path, "content/index.md")

    page_content = """
    ---
    title: Test Page
    layout: default
    ---

    # Test Page

    This is a test page.
    """

    File.mkdir_p!(Path.dirname(content_path))
    File.write!(content_path, page_content)

    {:ok, context |> Map.put(:css_reference, css_ref)}
  end

  step "an image exists at {string}", %{args: [image_path]} = context do
    site_path = context[:site_path]
    full_path = Path.join(site_path, image_path)

    # Create a minimal PNG file (1x1 transparent PNG)
    # This is a valid PNG file in binary format
    png_data =
      <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44,
        0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F,
        0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00,
        0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82>>

    File.mkdir_p!(Path.dirname(full_path))
    File.write!(full_path, png_data)

    {:ok,
     context
     |> Map.put(:original_image_path, full_path)
     |> Map.put(:original_image_data, png_data)}
  end

  # --- THEN Steps ---

  step "a minified CSS file should exist at {string}", %{args: [pattern]} = context do
    site_path = context[:site_path]

    # Pattern is like "_site/css/app-[hash].css"
    # Extract directory and filename pattern
    output_dir = Path.join(site_path, Path.dirname(pattern))

    assert File.dir?(output_dir),
           "Expected output directory to exist: #{output_dir}"

    # Look for files matching the pattern (with any hash)
    basename = Path.basename(pattern, ".css")
    # basename is "app-[hash]", we want "app-*.css"
    search_pattern = String.replace(basename, "[hash]", "*") <> ".css"
    matching_files = Path.wildcard(Path.join(output_dir, search_pattern))

    assert matching_files != [],
           "Expected to find CSS file matching pattern #{search_pattern} in #{output_dir}"

    # Store the actual file path for subsequent steps
    actual_file = List.first(matching_files)
    {:ok, context |> Map.put(:minified_css_file, actual_file)}
  end

  step "the file should not contain comments", context do
    # Check that the minified CSS file doesn't contain comments
    minified_file = context[:minified_css_file] || context[:minified_js_file]

    assert minified_file, "No minified file found in context"

    content = File.read!(minified_file)

    # Check for CSS comments /* */
    refute content =~ ~r/\/\*.*\*\//,
           "Expected minified file to not contain CSS comments"

    # Check for JS comments //
    refute content =~ ~r/\/\/.*/,
           "Expected minified file to not contain JS comments"

    {:ok, context}
  end

  step "the file size should be smaller than the original", context do
    original_size = context[:original_css_size]
    minified_file = context[:minified_css_file]

    assert minified_file && File.exists?(minified_file), "Minified file not found"

    minified_size = File.stat!(minified_file).size

    assert minified_size < original_size,
           "Expected minified file (#{minified_size} bytes) to be smaller than original (#{original_size} bytes)"

    {:ok, context}
  end

  step "a minified JS file should exist at {string}", %{args: [pattern]} = context do
    site_path = context[:site_path]

    # Pattern is like "_site/js/app-[hash].js"
    output_dir = Path.join(site_path, Path.dirname(pattern))

    assert File.dir?(output_dir),
           "Expected output directory to exist: #{output_dir}"

    # Look for files matching the pattern (with any hash)
    basename = Path.basename(pattern, ".js")
    search_pattern = String.replace(basename, "[hash]", "*") <> ".js"
    matching_files = Path.wildcard(Path.join(output_dir, search_pattern))

    assert matching_files != [],
           "Expected to find JS file matching pattern #{search_pattern} in #{output_dir}"

    # Store the actual file path for subsequent steps
    actual_file = List.first(matching_files)
    {:ok, context |> Map.put(:minified_js_file, actual_file)}
  end

  step "the rendered HTML should reference {string}", %{args: [pattern]} = context do
    site_path = context[:site_path]

    # The test creates a page that uses the layout
    # We need to create a dummy page first
    # Check if there are any HTML files in _site/
    output_dir = Path.join(site_path, "_site")
    html_files = Path.wildcard(Path.join(output_dir, "**/*.html"))

    assert html_files != [],
           "Expected to find at least one HTML file in #{output_dir}"

    # Check the first HTML file for the fingerprinted asset reference
    html_file = List.first(html_files)
    html_content = File.read!(html_file)

    # Pattern is like "/css/app-[hash].css"
    # We need to check that HTML contains something like "/css/app-abc12345.css"
    # Extract the base pattern: "/css/app-" and the extension ".css"
    pattern_regex =
      pattern
      |> String.replace("[hash]", "[a-f0-9]+")
      |> Regex.compile!()

    assert html_content =~ pattern_regex,
           "Expected HTML to contain reference matching #{pattern}, got: #{html_content}"

    {:ok, context}
  end

  step "the file should be copied to {string}", %{args: [target_path]} = context do
    site_path = context[:site_path]
    full_target_path = Path.join(site_path, target_path)

    # Check that file was copied to output directory
    assert File.exists?(full_target_path),
           "Expected file to be copied to: #{full_target_path}"

    {:ok, context |> Map.put(:copied_file_path, full_target_path)}
  end

  step "the file should be identical to the original", context do
    # Compare the copied file with the original
    copied_file = context[:copied_file_path]
    original_data = context[:original_image_data]

    assert copied_file && File.exists?(copied_file), "Copied file not found"

    copied_data = File.read!(copied_file)

    assert copied_data == original_data,
           "Expected copied file to be identical to original"

    {:ok, context}
  end
end
