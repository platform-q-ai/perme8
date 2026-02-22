defmodule AgentsWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :agents_web,
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
      compilers: [:boundary, :phoenix_live_view] ++ Mix.compilers(),
      boundary: boundary(),
      listeners: [Phoenix.CodeReloader],
      test_pattern: "*_test.exs"
    ]
  end

  def application do
    [
      mod: {AgentsWeb.Application, []},
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
            {:phoenix_live_view, :relaxed},
            {:phoenix_html, :relaxed},
            {:phoenix_ecto, :relaxed},
            {:agents, :relaxed},
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
      {:phoenix, "~> 1.8.1"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:gettext, "~> 0.26"},
      {:agents, in_umbrella: true},
      {:identity, in_umbrella: true},
      {:jarga, in_umbrella: true},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"},
      {:boundary, "~> 0.10", runtime: false},
      {:lazy_html, ">= 0.1.0", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind agents", "esbuild agents"],
      "assets.deploy": [
        "tailwind agents --minify",
        "esbuild agents --minify",
        "phx.digest"
      ],
      test: ["test"]
    ]
  end
end
