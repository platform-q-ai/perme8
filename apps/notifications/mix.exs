defmodule Notifications.MixProject do
  use Mix.Project

  def project do
    [
      app: :notifications,
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
      mod: {Notifications.OTPApp, []},
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
      {:perme8_events, in_umbrella: true},
      {:identity, in_umbrella: true},

      # Architecture
      {:boundary, "~> 0.10", runtime: false},

      # Database
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},

      # PubSub
      {:phoenix_pubsub, "~> 2.1"},

      # Utilities
      {:jason, "~> 1.2"},

      # Testing
      {:mox, "~> 1.0", only: :test}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
