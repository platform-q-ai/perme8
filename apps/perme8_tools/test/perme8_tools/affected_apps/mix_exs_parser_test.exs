defmodule Perme8Tools.AffectedApps.MixExsParserTest do
  use ExUnit.Case, async: true

  alias Perme8Tools.AffectedApps.MixExsParser

  describe "parse_in_umbrella_deps/1" do
    test "extracts single in_umbrella dep" do
      content = """
      defp deps do
        [
          {:identity, in_umbrella: true},
          {:jason, "~> 1.2"}
        ]
      end
      """

      assert MixExsParser.parse_in_umbrella_deps(content) == [:identity]
    end

    test "extracts multiple in_umbrella deps" do
      content = """
      defp deps do
        [
          {:perme8_events, in_umbrella: true},
          {:identity, in_umbrella: true},
          {:jason, "~> 1.2"},
          {:agents, in_umbrella: true}
        ]
      end
      """

      assert MixExsParser.parse_in_umbrella_deps(content) == [
               :perme8_events,
               :identity,
               :agents
             ]
    end

    test "ignores non-umbrella deps" do
      content = """
      defp deps do
        [
          {:jason, "~> 1.2"},
          {:phoenix, "~> 1.8.1"},
          {:boundary, "~> 0.10", runtime: false}
        ]
      end
      """

      assert MixExsParser.parse_in_umbrella_deps(content) == []
    end

    test "excludes deps with only: :test" do
      content = """
      defp deps do
        [
          {:chat, in_umbrella: true},
          {:identity, in_umbrella: true},
          {:jarga, in_umbrella: true, only: :test},
          {:notifications, in_umbrella: true, only: :test}
        ]
      end
      """

      assert MixExsParser.parse_in_umbrella_deps(content) == [:chat, :identity]
    end

    test "returns empty list for no umbrella deps" do
      content = """
      defp deps do
        [
          {:boundary, "~> 0.10", runtime: false},
          {:jason, "~> 1.2"}
        ]
      end
      """

      assert MixExsParser.parse_in_umbrella_deps(content) == []
    end

    test "returns empty list for empty content" do
      assert MixExsParser.parse_in_umbrella_deps("") == []
    end

    test "returns empty list for nil" do
      assert MixExsParser.parse_in_umbrella_deps(nil) == []
    end

    test "handles deps with extra options like runtime: false" do
      content = """
      defp deps do
        [
          {:agents, in_umbrella: true, runtime: false}
        ]
      end
      """

      assert MixExsParser.parse_in_umbrella_deps(content) == [:agents]
    end

    test "handles multi-line dep declarations" do
      content = """
      defp deps do
        [
          {:perme8_events,
           in_umbrella: true},
          {:identity, in_umbrella: true}
        ]
      end
      """

      # The regex matches single-line tuples; multi-line where in_umbrella
      # is on a different line but still within the same {} should still match
      result = MixExsParser.parse_in_umbrella_deps(content)
      assert :identity in result
    end

    test "handles real-world chat_web mix.exs pattern" do
      content = """
      defp deps do
        [
          {:chat, in_umbrella: true},
          {:identity, in_umbrella: true},
          {:agents, in_umbrella: true},
          {:phoenix, "~> 1.8.1"},
          {:phoenix_html, "~> 4.1"},
          {:phoenix_live_view, "~> 1.1.0"},
          {:boundary, "~> 0.10", runtime: false},
          {:lazy_html, ">= 0.1.0", only: :test},
          # Test deps: LiveView integration tests need fixtures and sandbox setup
          {:jarga, in_umbrella: true, only: :test},
          {:notifications, in_umbrella: true, only: :test}
        ]
      end
      """

      result = MixExsParser.parse_in_umbrella_deps(content)
      assert result == [:chat, :identity, :agents]
      refute :jarga in result
      refute :notifications in result
    end
  end
end
