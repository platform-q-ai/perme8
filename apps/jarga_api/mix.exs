defmodule JargaApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :jarga_api,
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
      listeners: [Phoenix.CodeReloader],
      test_pattern: "*_test.exs"
    ]
  end

  # Configuration for the OTP application.
  def application do
    [
      mod: {JargaApi.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Boundary configuration for enforcing architectural layers
  defp boundary do
    [
      externals_mode: :relaxed,
      default: [
        check: [
          apps: [
            {:phoenix, :relaxed},
            {:phoenix_ecto, :relaxed},
            {:jarga, :relaxed}
          ]
        ]
      ],
      ignore: [~r/\.Test\./]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.8.1"},
      {:jarga, in_umbrella: true},
      {:identity, in_umbrella: true},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"},
      {:boundary, "~> 0.10", runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["test"]
    ]
  end
end
