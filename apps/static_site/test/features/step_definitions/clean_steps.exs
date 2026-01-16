defmodule StaticSite.CleanSteps do
  use Cucumber.StepDefinition
  use ExUnit.Case

  # --- GIVEN Steps ---

  step "the output directory {string} exists with files", %{args: [output_dir]} = context do
    site_path = context[:site_path]
    output_path = Path.join(site_path, output_dir)

    # Create output directory with some files
    File.mkdir_p!(output_path)
    File.write!(Path.join(output_path, "index.html"), "<html>Old content</html>")
    File.write!(Path.join(output_path, "post.html"), "<html>Old post</html>")

    {:ok, context |> Map.put(:output_path, output_path)}
  end

  step "the output directory {string} exists with stale files", %{args: [output_dir]} = context do
    site_path = context[:site_path]
    output_path = Path.join(site_path, output_dir)

    # Create output directory with stale files
    File.mkdir_p!(output_path)
    File.write!(Path.join(output_path, "deleted-post.html"), "<html>Deleted content</html>")
    File.write!(Path.join(output_path, "old-page.html"), "<html>Old page</html>")

    {:ok,
     context
     |> Map.put(:output_path, output_path)
     |> Map.put(:stale_files, ["deleted-post.html", "old-page.html"])}
  end

  # --- THEN Steps ---

  step "the directory {string} should not exist", %{args: [dir_name]} = context do
    site_path = context[:site_path]
    dir_path = Path.join(site_path, dir_name)

    refute File.exists?(dir_path),
           "Expected directory #{dir_name} to not exist, but it does at: #{dir_path}"

    {:ok, context}
  end

  step "I should see success message {string}", %{args: [expected_message]} = context do
    output = context[:command_output] || ""

    assert output =~ expected_message,
           "Expected to see '#{expected_message}' in output. Got: #{output}"

    {:ok, context}
  end

  step "the output should not contain stale files", context do
    output_path = context[:output_path]
    stale_files = context[:stale_files] || []

    # Check that stale files don't exist
    Enum.each(stale_files, fn file ->
      file_path = Path.join(output_path, file)

      refute File.exists?(file_path),
             "Expected stale file #{file} to not exist, but it does at: #{file_path}"
    end)

    {:ok, context}
  end
end
