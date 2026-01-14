defmodule Jarga.MixProject do
  use Mix.Project

  def project do
    [
      app: :jarga,
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
      # Exclude .feature files from test pattern (Cucumber handles these)
      test_pattern: "*_test.exs",
      test_coverage: [
        tool: ExCoveralls
      ],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Jarga.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test, "assets.deploy": :prod]
    ]
  end

  # Specifies which paths to compile per environment.
  # Note: test/features/step_definitions is loaded by Cucumber, not elixirc
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Boundary configuration for enforcing architectural layers
  defp boundary do
    [
      # Only warn about calls crossing internal application boundaries
      # Framework dependencies (Ecto, Phoenix) are not checked
      externals_mode: :relaxed,

      # NOTE: All modules now have boundary declarations:
      # - Jarga: Parent boundary for domain contexts
      # - JargaApp: OTP application boundary (renamed from Jarga.Application)
      # - JargaWeb: Web interface boundary
      # All boundaries properly declared to avoid namespace hierarchy conflicts.

      # Specific framework apps we allow (not strictly checked due to relaxed mode)
      default: [
        check: [
          apps: [
            # Web framework
            {:phoenix, :relaxed},
            {:phoenix_live_view, :relaxed},
            {:phoenix_html, :relaxed},
            {:phoenix_ecto, :relaxed},
            # Database
            {:ecto, :relaxed},
            {:ecto_sql, :relaxed},
            # Other - allow Mix for compile tasks
            {:mix, :relaxed}
          ]
        ]
      ],
      # Ignore test helper modules from boundary checks
      ignore: [~r/\.Test\./]
    ]
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix_ecto, "~> 4.6"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.1.0"},
      {:swoosh, "~> 1.16"},
      {:finch, "~> 0.13"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:dotenvy, "~> 0.8.0", only: [:dev, :test]},
      {:boundary, "~> 0.10", runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 1.0", only: :test},
      {:cucumber, "~> 0.4.2", only: :test},
      {:slugy, "~> 4.1"},
      {:mdex, "~> 0.2"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
