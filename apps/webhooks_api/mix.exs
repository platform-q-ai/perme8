defmodule WebhooksApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :webhooks_api,
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

  def application do
    [
      mod: {WebhooksApi.Application, []},
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
            {:phoenix_ecto, :relaxed},
            {:ecto, :relaxed},
            {:ecto_sql, :relaxed},
            {:jarga, :relaxed},
            {:identity, :relaxed},
            {:webhooks, :relaxed}
          ]
        ]
      ],
      ignore: [~r/\.Test\./]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.8.1"},
      {:webhooks, in_umbrella: true},
      {:identity, in_umbrella: true},
      {:jarga, in_umbrella: true},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_ecto, "~> 4.6"},
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
