defmodule KnowledgeMcp.MixProject do
  use Mix.Project

  def project do
    [
      app: :knowledge_mcp,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:boundary] ++ Mix.compilers(),
      boundary: boundary()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {KnowledgeMcp.Application, []}
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
      {:hermes_mcp, "~> 0.14"},
      {:jason, "~> 1.2"},
      {:boundary, "~> 0.10", runtime: false},
      {:mox, "~> 1.0", only: :test},
      {:identity, in_umbrella: true},
      {:entity_relationship_manager, in_umbrella: true}
    ]
  end
end
