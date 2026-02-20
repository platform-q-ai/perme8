defmodule ExoDashboard.Features.Infrastructure.FeatureFileScannerTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.Features.Infrastructure.FeatureFileScanner

  describe "scan/0" do
    test "returns a list of .feature file paths from the umbrella" do
      results = FeatureFileScanner.scan()

      assert is_list(results)
      # Every result should be a string ending in .feature
      Enum.each(results, fn path ->
        assert is_binary(path)
        assert String.ends_with?(path, ".feature")
      end)
    end

    test "returns absolute paths" do
      results = FeatureFileScanner.scan()

      Enum.each(results, fn path ->
        assert String.starts_with?(path, "/")
      end)
    end
  end

  describe "scan/1 with custom base path" do
    test "scans the given directory for .feature files" do
      # Create a temp dir with a fixture .feature file
      tmp_dir = System.tmp_dir!()
      test_dir = Path.join(tmp_dir, "exo_scanner_test_#{:rand.uniform(100_000)}")
      feature_dir = Path.join([test_dir, "apps", "test_app", "test", "features"])
      File.mkdir_p!(feature_dir)

      feature_path = Path.join(feature_dir, "sample.browser.feature")
      File.write!(feature_path, "Feature: Sample\n  Scenario: Test\n    Given something\n")

      try do
        results = FeatureFileScanner.scan(test_dir)

        assert is_list(results)
        assert length(results) == 1
        assert hd(results) == feature_path
      after
        File.rm_rf!(test_dir)
      end
    end

    test "returns empty list when no .feature files exist" do
      tmp_dir = System.tmp_dir!()
      test_dir = Path.join(tmp_dir, "exo_scanner_empty_#{:rand.uniform(100_000)}")
      File.mkdir_p!(test_dir)

      try do
        results = FeatureFileScanner.scan(test_dir)
        assert results == []
      after
        File.rm_rf!(test_dir)
      end
    end
  end
end
