defmodule Perme8Tools.AffectedApps.FileClassifierTest do
  use ExUnit.Case, async: true

  alias Perme8Tools.AffectedApps.FileClassifier

  @known_apps [
    :agents,
    :agents_api,
    :agents_web,
    :alkali,
    :chat,
    :chat_web,
    :entity_relationship_manager,
    :exo_dashboard,
    :identity,
    :jarga,
    :jarga_api,
    :jarga_web,
    :notifications,
    :perme8_events,
    :perme8_plugs,
    :perme8_tools,
    :webhooks,
    :webhooks_api
  ]

  describe "classify/2" do
    test "classifies app code file" do
      assert FileClassifier.classify("apps/identity/lib/identity/users.ex", @known_apps) ==
               {:app, :identity, :code}
    end

    test "classifies app test file" do
      assert FileClassifier.classify("apps/agents/test/agents/sessions_test.exs", @known_apps) ==
               {:app, :agents, :test}
    end

    test "classifies shared config as all_apps" do
      assert FileClassifier.classify("config/config.exs", @known_apps) == :all_apps
    end

    test "classifies root mix.exs as all_apps" do
      assert FileClassifier.classify("mix.exs", @known_apps) == :all_apps
    end

    test "classifies mix.lock as all_apps" do
      assert FileClassifier.classify("mix.lock", @known_apps) == :all_apps
    end

    test "classifies .tool-versions as all_apps" do
      assert FileClassifier.classify(".tool-versions", @known_apps) == :all_apps
    end

    test "classifies .formatter.exs as all_apps" do
      assert FileClassifier.classify(".formatter.exs", @known_apps) == :all_apps
    end

    test "classifies config subdirectory as all_apps" do
      assert FileClassifier.classify("config/test.exs", @known_apps) == :all_apps
    end

    test "classifies tools/exo-bdd as all_exo_bdd" do
      assert FileClassifier.classify("tools/exo-bdd/src/runner.ts", @known_apps) == :all_exo_bdd
    end

    test "classifies docs as ignore" do
      assert FileClassifier.classify("docs/some-doc.md", @known_apps) == :ignore
    end

    test "classifies scripts as ignore" do
      assert FileClassifier.classify("scripts/deploy.sh", @known_apps) == :ignore
    end

    test "classifies .github as ignore" do
      assert FileClassifier.classify(".github/workflows/ci.yml", @known_apps) == :ignore
    end

    test "classifies non-code file in app as ignore" do
      assert FileClassifier.classify("apps/agents/README.md", @known_apps) == :ignore
    end

    test "classifies empty string as ignore" do
      assert FileClassifier.classify("", @known_apps) == :ignore
    end

    test "classifies unknown path as ignore" do
      assert FileClassifier.classify("random/path/file.txt", @known_apps) == :ignore
    end

    test "classifies migration file as code" do
      assert FileClassifier.classify(
               "apps/agents/priv/repo/migrations/123_create.exs",
               @known_apps
             ) == {:app, :agents, :code}
    end

    test "classifies TypeScript asset as code" do
      assert FileClassifier.classify("apps/agents_web/assets/js/app.ts", @known_apps) ==
               {:app, :agents_web, :code}
    end

    test "classifies .heex template as code" do
      assert FileClassifier.classify(
               "apps/jarga_web/lib/jarga_web/live/page.html.heex",
               @known_apps
             ) == {:app, :jarga_web, :code}
    end

    test "classifies feature file as test" do
      assert FileClassifier.classify(
               "apps/agents_web/test/features/sessions.feature",
               @known_apps
             ) == {:app, :agents_web, :test}
    end

    test "classifies entity_relationship_manager correctly" do
      assert FileClassifier.classify(
               "apps/entity_relationship_manager/lib/entity_relationship_manager.ex",
               @known_apps
             ) == {:app, :entity_relationship_manager, :code}
    end

    test "classifies perme8_tools code file" do
      assert FileClassifier.classify(
               "apps/perme8_tools/lib/mix/tasks/affected_apps.ex",
               @known_apps
             ) == {:app, :perme8_tools, :code}
    end

    test "ignores unknown app directory" do
      assert FileClassifier.classify("apps/unknown_app/lib/foo.ex", @known_apps) == :ignore
    end

    test "classifies app-level .formatter.exs as code" do
      assert FileClassifier.classify("apps/agents/.formatter.exs", @known_apps) ==
               {:app, :agents, :code}
    end

    test "classifies CSS file as code" do
      assert FileClassifier.classify("apps/jarga_web/assets/css/app.css", @known_apps) ==
               {:app, :jarga_web, :code}
    end

    test "classifies JSON file as code" do
      assert FileClassifier.classify("apps/alkali/package.json", @known_apps) ==
               {:app, :alkali, :code}
    end
  end

  describe "classify_all/2" do
    test "aggregates multiple files" do
      files = [
        "apps/identity/lib/identity/users.ex",
        "apps/agents/lib/agents/sessions.ex"
      ]

      result = FileClassifier.classify_all(files, @known_apps)

      assert result.directly_affected == MapSet.new([:identity, :agents])
      assert result.all_apps? == false
      assert result.all_exo_bdd? == false
    end

    test "sets all_apps flag when shared config changes" do
      files = [
        "config/config.exs",
        "apps/identity/lib/identity/users.ex"
      ]

      result = FileClassifier.classify_all(files, @known_apps)

      assert result.all_apps? == true
      assert :identity in result.directly_affected
    end

    test "sets all_exo_bdd flag when exo-bdd framework changes" do
      files = ["tools/exo-bdd/src/runner.ts"]

      result = FileClassifier.classify_all(files, @known_apps)

      assert result.all_exo_bdd? == true
      assert result.directly_affected == MapSet.new()
    end

    test "ignores non-code files" do
      files = [
        "docs/README.md",
        "scripts/deploy.sh",
        "apps/agents/README.md"
      ]

      result = FileClassifier.classify_all(files, @known_apps)

      assert result.directly_affected == MapSet.new()
      assert result.all_apps? == false
      assert result.all_exo_bdd? == false
    end

    test "returns empty result for empty file list" do
      result = FileClassifier.classify_all([], @known_apps)

      assert result.directly_affected == MapSet.new()
      assert result.all_apps? == false
      assert result.all_exo_bdd? == false
    end

    test "deduplicates app names from multiple files" do
      files = [
        "apps/identity/lib/identity/users.ex",
        "apps/identity/lib/identity/sessions.ex"
      ]

      result = FileClassifier.classify_all(files, @known_apps)

      assert result.directly_affected == MapSet.new([:identity])
    end
  end
end
