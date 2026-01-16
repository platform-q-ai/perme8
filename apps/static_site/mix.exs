defmodule StaticSite.MixProject do
  use Mix.Project

  def project do
    [
      app: :static_site,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_pattern: "*_test.exs",
      # Exclude .feature files from test pattern (Cucumber handles these)
      test_paths: ["test"],
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {StaticSite.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # BDD testing
      {:cucumber, "~> 0.4.2", only: :test},

      # HTML parsing for tests
      {:floki, "~> 0.36.0", only: :test},

      # Environment configuration
      {:dotenvy, "~> 0.8.0", only: [:dev, :test]},

      # JSON encoding/decoding for build cache
      {:jason, "~> 1.4"}

      # Dependencies for static site generation
      # {:mdex, "~> 0.2"},
      # {:yaml_elixir, "~> 2.9"},
      # {:phoenix, "~> 1.7"},
      # {:phoenix_html, "~> 4.0"}
    ]
  end
end
