defmodule StaticSite.PostSteps do
  use Cucumber.StepDefinition
  use ExUnit.Case

  # --- THEN Steps ---

  step "a file should be created at {string}", %{args: [file_path]} = context do
    site_path = context[:site_path] || context[:tmp_dir]

    # Handle date placeholders in filenames (e.g., 2024-01-15-post-title.md)
    # Extract the title part without the date prefix
    expected_basename = Path.basename(file_path)

    # If filename starts with a date pattern, extract just the title part
    title_pattern =
      if Regex.match?(~r/^\d{4}-\d{2}-\d{2}-/, expected_basename) do
        # Remove the date prefix to get the title part
        String.replace(expected_basename, ~r/^\d{4}-\d{2}-\d{2}-/, "")
      else
        expected_basename
      end

    content_dir = Path.join(site_path, Path.dirname(file_path))

    if File.dir?(content_dir) do
      # Find files matching the title pattern (with any date)
      files = File.ls!(content_dir)

      file_exists =
        Enum.any?(files, fn f ->
          # Check if file ends with the title pattern (allowing any date prefix)
          String.ends_with?(f, title_pattern) || f == expected_basename
        end)

      # Find the actual created file for later steps
      created_file =
        Enum.find(files, fn f ->
          String.ends_with?(f, title_pattern) || f == expected_basename
        end)

      assert file_exists,
             "Expected file matching '#{title_pattern}' to be created in #{content_dir}. Found files: #{inspect(files)}"

      full_created_path = if created_file, do: Path.join(content_dir, created_file), else: nil
      {:ok, context |> Map.put(:created_file_path, full_created_path)}
    else
      # Directory doesn't exist, try direct file check
      full_path = Path.join(site_path, file_path)

      assert File.exists?(full_path),
             "Expected file to exist at: #{full_path}"

      {:ok, context |> Map.put(:created_file_path, full_path)}
    end
  end

  step "the file should contain frontmatter with:", context do
    file_path = context[:created_file_path]
    table_data = context.datatable.maps

    if File.exists?(file_path) do
      content = File.read!(file_path)

      # Check each expected field
      Enum.each(table_data, fn row ->
        field = row["Field"]
        expected_value = row["Value"]

        assert content =~ "#{field}:",
               "Expected frontmatter to contain field '#{field}' in file: #{file_path}"

        assert content =~ expected_value,
               "Expected frontmatter field '#{field}' to have value '#{expected_value}' in file: #{file_path}"
      end)
    end

    context
  end

  step "the frontmatter should have date field with today's date", context do
    file_path = context[:created_file_path]
    today = Date.utc_today() |> Date.to_iso8601()

    if File.exists?(file_path) do
      content = File.read!(file_path)

      assert content =~ "date:",
             "Expected frontmatter to contain 'date:' field in file: #{file_path}"

      assert content =~ today,
             "Expected frontmatter date to be today's date (#{today}) in file: #{file_path}"
    end

    {:ok, context}
  end

  step "I should see success message showing file path", context do
    output = context[:command_output] || ""

    # Success message should mention the created file
    assert output =~ "content/posts" || output =~ "Created",
           "Expected success message showing file path. Got: #{output}"

    {:ok, context}
  end
end
