defmodule Alkali.ScaffoldSteps do
  use Cucumber.StepDefinition
  use ExUnit.Case

  # --- GIVEN Steps ---

  step "a directory {string} already exists", %{args: [dirname]} = context do
    tmp_dir = System.tmp_dir!() <> "/alkali_test_#{:os.system_time(:millisecond)}"
    File.rm_rf!(tmp_dir)
    File.mkdir_p!(tmp_dir)
    target_path = Path.join(tmp_dir, dirname)
    File.mkdir_p!(target_path)

    {:ok, context |> Map.put(:tmp_dir, tmp_dir) |> Map.put(:existing_dir, target_path)}
  end

  # --- THEN Steps ---

  step "the following directories should be created:", context do
    tmp_dir = context[:tmp_dir]
    table_data = context.datatable.maps

    Enum.each(table_data, fn row ->
      dir_path = Path.join(tmp_dir, row["Directory"])
      assert File.dir?(dir_path), "Expected directory to exist: #{row["Directory"]}"
    end)

    context
  end

  step "the following files should be created:", context do
    tmp_dir = context[:tmp_dir]
    table_data = context.datatable.maps

    Enum.each(table_data, fn row ->
      expected_file = row["File"]

      # Handle date placeholders in filenames (e.g., 2024-01-15-welcome.md)
      # If the expected file contains a date pattern, match any date
      if String.contains?(expected_file, "2024-01-15-") do
        # Extract the directory and filename pattern
        parts = Path.split(expected_file)
        dir_path = parts |> Enum.slice(0..-2//1) |> Path.join()
        filename_pattern = parts |> List.last() |> String.replace("2024-01-15-", "")

        # Check if any file matching the pattern exists in that directory
        full_dir = Path.join(tmp_dir, dir_path)

        if File.dir?(full_dir) do
          files = File.ls!(full_dir)
          matching_files = Enum.filter(files, &String.ends_with?(&1, filename_pattern))

          assert length(matching_files) > 0,
                 "Expected file matching '#{filename_pattern}' to be created in #{dir_path}. Found files: #{inspect(files)}"
        else
          assert false, "Expected directory to exist: #{dir_path}"
        end
      else
        # Exact match for non-dated files
        file_path = Path.join(tmp_dir, expected_file)
        assert File.exists?(file_path), "Expected file to exist: #{expected_file}"
      end
    end)

    context
  end

  step "I should see success message with next steps", context do
    output = context[:command_output]
    assert output =~ "Next steps", "Expected success message with 'Next steps', got: #{output}"
    {:ok, context}
  end
end
