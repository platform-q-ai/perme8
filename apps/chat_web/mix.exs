defmodule ChatWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :chat_web,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:boundary, :phoenix_live_view] ++ Mix.compilers(),
      boundary: boundary(),
      test_pattern: "*_test.exs"
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp boundary do
    [
      externals_mode: :relaxed,
      ignore: [~r/\.Test\./]
    ]
  end

  defp deps do
    [
      {:chat, in_umbrella: true},
      {:identity, in_umbrella: true},
      {:agents, in_umbrella: true},
      {:phoenix, "~> 1.8.1"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.1.0"},
      {:boundary, "~> 0.10", runtime: false},
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end
end
