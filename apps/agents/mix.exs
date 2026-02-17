defmodule Agents.MixProject do
  use Mix.Project

  def project do
    [
      app: :agents,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:boundary] ++ Mix.compilers(),
      boundary: boundary(),
      test_pattern: "*_test.exs"
    ]
  end

  def application do
    [
      mod: {Agents.OTPApp, []},
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp boundary do
    [
      externals_mode: :relaxed,
      ignore: [~r/\.Test\./, ~r/\.Mocks\./]
    ]
  end

  defp deps do
    [
      # Umbrella dependencies
      {:identity, in_umbrella: true},

      # Architecture
      {:boundary, "~> 0.10", runtime: false},

      # Database
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},

      # PubSub
      {:phoenix_pubsub, "~> 2.1"},

      # HTTP client
      {:req, "~> 0.5"},

      # Utilities
      {:jason, "~> 1.2"},
      {:decimal, "~> 2.0"},

      # MCP
      {:hermes_mcp, "~> 0.14"},
      {:bandit, "~> 1.0"},

      # Testing
      {:mox, "~> 1.0", only: :test},
      {:bypass, "~> 2.1", only: :test}
    ]
  end

  defp aliases do
    [
      test: ["test"]
    ]
  end
end
