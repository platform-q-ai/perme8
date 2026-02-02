defmodule Alkali.MixProject do
  use Mix.Project

  def project do
    [
      app: :alkali,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      compilers: [:boundary] ++ Mix.compilers(),
      deps: deps(),
      test_pattern: "*_test.exs",
      # Exclude .feature files from test pattern (Cucumber handles these)
      test_paths: ["test"],
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex.pm package metadata
      description: "A fast, modern static site generator built with Elixir",
      package: package(),

      # Documentation
      name: "Alkali",
      source_url: "https://github.com/platform-q-ai/perme8/tree/main/apps/alkali",
      homepage_url: "https://github.com/platform-q-ai/perme8/tree/main/apps/alkali",
      docs: [
        main: "Alkali",
        extras: ["README.md"]
      ]
    ]
  end

  defp package do
    [
      name: :alkali,
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/platform-q-ai/perme8/tree/main/apps/alkali",
        "Docs" => "https://hexdocs.pm/alkali"
      },
      maintainers: ["akal1k0"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Alkali.Application, []}
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
      {:jason, "~> 1.4"},

      # Documentation
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},

      # Code quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},

      # Architecture boundary enforcement
      {:boundary, "~> 0.10", runtime: false}

      # Dependencies for static site generation
      # {:mdex, "~> 0.2"},
      # {:yaml_elixir, "~> 2.9"},
      # {:phoenix, "~> 1.7"},
      # {:phoenix_html, "~> 4.0"}
    ]
  end
end
