defmodule Perme8Plugs.MixProject do
  use Mix.Project

  def project do
    [
      app: :perme8_plugs,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:boundary] ++ Mix.compilers(),
      boundary: boundary()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
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
      # Plug behaviour and connection utilities
      {:plug, "~> 1.16"},
      # Architecture enforcement
      {:boundary, "~> 0.10", runtime: false}
    ]
  end
end
