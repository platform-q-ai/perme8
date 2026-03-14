defmodule Mix.Tasks.AffectedAppsTest do
  # NOT async -- integration tests that read real files and capture IO
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.AffectedApps

  describe "parse_args/1" do
    test "parses --json flag" do
      {opts, files} = AffectedApps.parse_args(["--json", "apps/identity/lib/identity.ex"])
      assert opts[:json] == true
      assert files == ["apps/identity/lib/identity.ex"]
    end

    test "parses --diff flag with branch name" do
      {opts, files} = AffectedApps.parse_args(["--diff", "main"])
      assert opts[:diff] == "main"
      assert files == []
    end

    test "parses --dry-run flag" do
      {opts, _files} = AffectedApps.parse_args(["--dry-run", "apps/identity/lib/identity.ex"])
      assert opts[:dry_run] == true
    end

    test "parses file arguments" do
      {_opts, files} =
        AffectedApps.parse_args([
          "apps/identity/lib/identity.ex",
          "apps/agents/lib/agents.ex"
        ])

      assert files == ["apps/identity/lib/identity.ex", "apps/agents/lib/agents.ex"]
    end

    test "parses short aliases" do
      {opts, _files} = AffectedApps.parse_args(["-j", "-d", "main"])
      assert opts[:json] == true
      assert opts[:diff] == "main"
    end
  end

  describe "run/1 integration" do
    test "identity file includes identity and dependents in output" do
      output =
        capture_io(fn ->
          AffectedApps.run(["apps/identity/lib/identity.ex"])
        end)

      assert output =~ "identity"
      assert output =~ "agents"
      assert output =~ "jarga"
    end

    test "config change triggers all apps" do
      output =
        capture_io(fn ->
          AffectedApps.run(["config/config.exs"])
        end)

      assert output =~ "ALL"
    end

    test "alkali only triggers itself" do
      output =
        capture_io(fn ->
          AffectedApps.run(["apps/alkali/lib/alkali.ex"])
        end)

      assert output =~ "alkali"
      # Should show only 1 app affected
      assert output =~ "Affected apps (1)"
    end

    test "json output is valid JSON" do
      output =
        capture_io(fn ->
          AffectedApps.run(["--json", "apps/identity/lib/identity.ex"])
        end)

      assert {:ok, decoded} = Jason.decode(output)
      assert "identity" in decoded["affected_apps"]
      assert "agents" in decoded["affected_apps"]
    end

    test "tools/exo-bdd triggers all exo-bdd combos but no unit test paths" do
      output =
        capture_io(fn ->
          AffectedApps.run(["--json", "tools/exo-bdd/src/runner.ts"])
        end)

      {:ok, decoded} = Jason.decode(output)
      assert decoded["all_exo_bdd"] == true
      assert decoded["affected_apps"] == []
      assert length(decoded["exo_bdd_combos"]) == 18
    end

    test "docs file triggers no affected apps" do
      output =
        capture_io(fn ->
          AffectedApps.run(["--json", "docs/README.md"])
        end)

      {:ok, decoded} = Jason.decode(output)
      assert decoded["affected_apps"] == []
      assert decoded["exo_bdd_combos"] == []
    end

    test "json output for jarga includes fan-out exo-bdd combos" do
      output =
        capture_io(fn ->
          AffectedApps.run(["--json", "apps/jarga/lib/jarga.ex"])
        end)

      {:ok, decoded} = Jason.decode(output)

      exo_apps = Enum.map(decoded["exo_bdd_combos"], & &1["app"]) |> Enum.uniq() |> Enum.sort()
      assert "jarga-web" in exo_apps
      assert "jarga-api" in exo_apps
      assert "erm" in exo_apps
    end

    test "multiple files across apps unions results" do
      output =
        capture_io(fn ->
          AffectedApps.run([
            "--json",
            "apps/identity/lib/identity.ex",
            "apps/alkali/lib/alkali.ex"
          ])
        end)

      {:ok, decoded} = Jason.decode(output)
      assert "identity" in decoded["affected_apps"]
      assert "alkali" in decoded["affected_apps"]
      assert "agents" in decoded["affected_apps"]
    end

    test "perme8_events propagates to most apps" do
      output =
        capture_io(fn ->
          AffectedApps.run(["--json", "apps/perme8_events/lib/perme8_events.ex"])
        end)

      {:ok, decoded} = Jason.decode(output)
      assert "identity" in decoded["affected_apps"]
      assert "agents" in decoded["affected_apps"]
      assert "jarga" in decoded["affected_apps"]
      refute "alkali" in decoded["affected_apps"]
    end

    test "dry-run mode shows commands" do
      output =
        capture_io(fn ->
          AffectedApps.run(["--dry-run", "apps/alkali/lib/alkali.ex"])
        end)

      assert output =~ "mix test"
      assert output =~ "dry-run"
    end

    test "completes in under 2 seconds" do
      {time_us, _} =
        :timer.tc(fn ->
          capture_io(fn ->
            AffectedApps.run(["apps/identity/lib/identity.ex"])
          end)
        end)

      # 2 seconds = 2_000_000 microseconds
      assert time_us < 2_000_000, "Took #{time_us / 1_000_000}s, expected < 2s"
    end
  end
end
