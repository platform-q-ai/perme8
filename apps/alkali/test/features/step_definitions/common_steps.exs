defmodule Alkali.CommonSteps do
  @moduledoc """
  Common step definitions shared across all static site feature tests.
  """

  use Cucumber.StepDefinition
  use ExUnit.Case
  import ExUnit.CaptureIO

  # --- WHEN Steps ---

  step "I run {string}", %{args: [command]} = context do
    # Use site_path if available (where the site files are), otherwise fall back to tmp_dir
    work_dir = context[:site_path] || context[:tmp_dir] || setup_temp_dir()

    {output, exit_code} =
      try do
        output =
          capture_io(fn ->
            File.cd!(work_dir, fn ->
              # Parse command with proper quote handling
              {task_name, args} = parse_command(command)

              # Execute the appropriate Mix task based on task_name
              case task_name do
                "alkali.new" -> Mix.Tasks.Alkali.New.run(args)
                "alkali.new.post" -> Mix.Tasks.Alkali.New.Post.run(args)
                "alkali.build" -> Mix.Tasks.Alkali.Build.run(args)
                "alkali.post" -> Mix.Tasks.Alkali.Post.run(args)
                "alkali.clean" -> Mix.Tasks.Alkali.Clean.run(args)
                _ -> :ok
              end
            end)
          end)

        {output, 0}
      rescue
        e in Mix.Error -> {"Error: #{e.message}", 1}
        e -> {"Error: #{Exception.message(e)}", 1}
      end

    {:ok,
     context
     |> Map.put(:command_output, output)
     |> Map.put(:exit_code, exit_code)
     |> Map.put(:tmp_dir, context[:tmp_dir] || work_dir)}
  end

  # --- THEN Steps (Command) ---

  step "the command should succeed", context do
    assert context[:exit_code] == 0,
           "Expected command to succeed but got exit code #{context[:exit_code]}. Output: #{context[:command_output]}"

    {:ok, context}
  end

  step "the command should fail", context do
    assert context[:exit_code] != 0,
           "Expected command to fail but it succeeded. Output: #{context[:command_output]}"

    {:ok, context}
  end

  # --- THEN Steps (Output) ---

  step "I should see {string}", %{args: [expected_text]} = context do
    output = context[:command_output] || ""

    assert output =~ expected_text,
           "Expected '#{expected_text}' in output. Got: #{output}"

    {:ok, context}
  end

  step "I should see error {string}", %{args: [error_text]} = context do
    output = context[:command_output] || ""

    assert output =~ error_text,
           "Expected error '#{error_text}' in output. Got: #{output}"

    {:ok, context}
  end

  step "I should see error containing:", context do
    output = context[:command_output] || ""

    # Handle both docstring and datatable formats
    cond do
      Map.has_key?(context, :docstring) ->
        error_text = String.trim(context.docstring)

        assert output =~ error_text,
               "Expected error containing '#{error_text}' in output. Got: #{output}"

        context

      Map.has_key?(context, :datatable) ->
        table_data = context.datatable.maps

        Enum.each(table_data, fn row ->
          error_text = row["Error"]

          assert output =~ error_text,
                 "Expected error containing '#{error_text}' in output. Got: #{output}"
        end)

        context

      true ->
        flunk("Step 'I should see error containing:' requires either docstring or datatable")
    end
  end

  # --- THEN Steps (Build) ---

  step "the build should succeed", context do
    assert context[:exit_code] == 0,
           "Expected build to succeed but got exit code #{context[:exit_code]}. Output: #{context[:command_output]}"

    {:ok, context}
  end

  step "the build should fail", context do
    assert context[:exit_code] != 0,
           "Expected build to fail but it succeeded. Output: #{context[:command_output]}"

    {:ok, context}
  end

  # --- Helper Functions ---

  defp setup_temp_dir do
    tmp_dir = System.tmp_dir!() <> "/alkali_test_#{:os.system_time(:millisecond)}"
    File.rm_rf!(tmp_dir)
    File.mkdir_p!(tmp_dir)
    tmp_dir
  end

  # Parse command string handling quoted arguments
  # Example: "mix alkali.new.post \"My Title\"" -> {"alkali.new.post", ["My Title"]}
  defp parse_command(command) do
    # Remove "mix " prefix if present
    command = String.replace_prefix(command, "mix ", "")

    # Split by spaces but keep quoted strings together
    parts = parse_args(command, [], "", false)

    case parts do
      [task_name | args] -> {task_name, args}
      [] -> {"", []}
    end
  end

  # Recursively parse command arguments, preserving quoted strings
  defp parse_args("", acc, current, _in_quotes) when current != "" do
    Enum.reverse([current | acc])
  end

  defp parse_args("", acc, _current, _in_quotes) do
    Enum.reverse(acc)
  end

  defp parse_args(<<char, rest::binary>>, acc, current, in_quotes) do
    case {char, in_quotes} do
      {?", false} ->
        # Start of double quoted string
        parse_args(rest, acc, current, true)

      {?", true} ->
        # End of double quoted string - save current and continue
        parse_args(rest, [current | acc], "", false)

      {?', false} ->
        # Start of single quoted string (treat like double quotes)
        parse_args(rest, acc, current, true)

      {?', true} ->
        # End of single quoted string - save current and continue
        parse_args(rest, [current | acc], "", false)

      {?\s, false} when current != "" ->
        # Space outside quotes - save current word
        parse_args(rest, [current | acc], "", false)

      {?\s, false} ->
        # Space outside quotes with no current word - skip
        parse_args(rest, acc, "", false)

      {c, _} ->
        # Regular character - add to current
        parse_args(rest, acc, current <> <<c>>, in_quotes)
    end
  end
end
