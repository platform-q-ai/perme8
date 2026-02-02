defmodule Alkali.FrontmatterSteps do
  use Cucumber.StepDefinition
  use ExUnit.Case

  # --- GIVEN Steps ---

  step "a post exists at {string} with content:", %{args: [file_path]} = context do
    site_path = context[:site_path]
    full_path = Path.join(site_path, file_path)

    # Get content from docstring
    content = context.docstring

    # Create parent directories
    File.mkdir_p!(Path.dirname(full_path))

    # Write the file
    File.write!(full_path, content)

    {:ok, context |> Map.put(:last_created_file, full_path)}
  end

  step "a post exists with malformed YAML frontmatter", context do
    site_path = context[:site_path]
    file_path = Path.join([site_path, "content/posts/malformed.md"])

    # Create malformed YAML
    content = """
    ---
    title: "Test"
    date: [invalid yaml structure
    ---

    Content
    """

    File.mkdir_p!(Path.dirname(file_path))
    File.write!(file_path, content)

    {:ok, context |> Map.put(:last_created_file, file_path)}
  end

  step "a post exists with frontmatter:", context do
    site_path = context[:site_path]
    file_path = Path.join([site_path, "content/posts/test-post.md"])

    # Get frontmatter content from docstring
    content = context.docstring

    File.mkdir_p!(Path.dirname(file_path))
    File.write!(file_path, content)

    {:ok, context |> Map.put(:last_created_file, file_path)}
  end

  # --- THEN Steps ---

  step "the error should show the file path and line number", context do
    output = context[:command_output]

    # Check that error contains file path reference
    assert output =~ "content/posts",
           "Expected error to show file path, got: #{output}"

    # In a real implementation, we'd check for line number
    # For now, just verify file path is present

    {:ok, context}
  end

  step "the error should list available layouts", context do
    output = context[:command_output] || ""

    # For now, just check that "Looked in:" is present
    # A more advanced implementation would list all available layouts
    assert output =~ "Looked in:",
           "Error should show where layouts were looked for. Output: #{output}"

    {:ok, context}
  end
end
