defmodule Webhooks.MixProject do
  use Mix.Project

  def project do
    [
      app: :webhooks,
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
      boundary: boundary()
    ]
  end

  def application do
    [
      mod: {Webhooks.App, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp boundary do
    [
      externals_mode: :relaxed,
      default: [
        check: [
          apps: [
            {:phoenix, :relaxed},
            {:ecto, :relaxed},
            {:ecto_sql, :relaxed},
            {:identity, :relaxed},
            {:jarga, :relaxed}
          ]
        ]
      ],
      ignore: [~r/\.Test\./]
    ]
  end

  defp deps do
    [
      {:identity, in_umbrella: true},
      {:jarga, in_umbrella: true},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_ecto, "~> 4.6"},
      {:req, "~> 0.5"},
      {:jason, "~> 1.4"},
      {:boundary, "~> 0.10", runtime: false},
      {:plug_crypto, "~> 2.0"},
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
