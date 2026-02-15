defmodule Perme8Tools.MixProject do
  use Mix.Project

  def project do
    [
      app: :perme8_tools,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:boundary] ++ Mix.compilers(),
      boundary: boundary()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Perme8Tools.Application, []}
    ]
  end

  # Boundary configuration - tools app doesn't need strict boundaries
  defp boundary do
    [
      externals_mode: :relaxed,
      default: [
        check: [
          apps: [
            {:mix, :relaxed}
          ]
        ]
      ],
      ignore: [~r/^Mix\.Tasks\./]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:boundary, "~> 0.10", runtime: false},
      {:jason, "~> 1.2"}
    ]
  end
end
