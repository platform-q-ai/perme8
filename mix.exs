defmodule Perme8.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      elixirc_options: [warnings_as_errors: true],
      listeners: [Phoenix.CodeReloader],
      deps: deps(),
      aliases: aliases(),
      releases: releases()
    ]
  end

  defp releases do
    [
      perme8: [
        applications: [
          perme8_events: :permanent,
          alkali: :permanent,
          identity: :permanent,
          jarga: :permanent,
          jarga_api: :permanent,
          jarga_web: :permanent
        ],
        overlay: "rel/overlays"
      ]
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
      setup: ["deps.get"],
      "boundary.spec": &run_boundary_spec/1,
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": [
        "tailwind jarga",
        "assets.copy_fonts",
        "esbuild jarga",
        "tailwind identity",
        "esbuild identity",
        "tailwind exo_dashboard",
        "esbuild exo_dashboard",
        "tailwind perme8_dashboard",
        "esbuild perme8_dashboard",
        "tailwind agents",
        "esbuild agents"
      ],
      "assets.deploy": [
        "tailwind jarga --minify",
        "assets.copy_fonts",
        "esbuild jarga --minify",
        "phx.digest apps/jarga_web/priv/static -o apps/jarga_web/priv/static",
        "tailwind identity --minify",
        "esbuild identity --minify",
        "phx.digest apps/identity/priv/static -o apps/identity/priv/static",
        "tailwind exo_dashboard --minify",
        "esbuild exo_dashboard --minify",
        "phx.digest apps/exo_dashboard/priv/static -o apps/exo_dashboard/priv/static",
        "tailwind perme8_dashboard --minify",
        "esbuild perme8_dashboard --minify",
        "phx.digest apps/perme8_dashboard/priv/static -o apps/perme8_dashboard/priv/static",
        "tailwind agents --minify",
        "esbuild agents --minify",
        "phx.digest apps/agents_web/priv/static -o apps/agents_web/priv/static"
      ],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format --check-formatted",
        "credo --strict",
        "check.behaviours",
        "step_linter",
        "check.ci_sync",
        "assets.build",
        fn _ ->
          if System.cmd("npm", ["test", "--prefix", "apps/jarga_web/assets"],
               into: IO.stream(:stdio, :line)
             )
             |> elem(1) != 0 do
            raise "npm test failed"
          end
        end,
        "test"
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        precommit: :test,
        "assets.build": :dev,
        "assets.deploy": :prod
      ]
    ]
  end

  # Run a boundary mix task in each umbrella app that has the :boundary compiler.
  # boundary.spec and boundary.check require the boundary compiler's ETS table,
  # which only exists per-app (not at the umbrella root).
  defp run_boundary_spec(_args), do: run_boundary_task("boundary.spec")

  defp run_boundary_task(task) do
    apps_path = Path.join(File.cwd!(), "apps")

    apps_path
    |> File.ls!()
    |> Enum.sort()
    |> Enum.each(fn app_dir ->
      app_path = Path.join(apps_path, app_dir)
      mix_file = Path.join(app_path, "mix.exs")

      if File.exists?(mix_file) && has_boundary_compiler?(mix_file) do
        Mix.shell().info([:cyan, "==> #{app_dir}", :reset])

        case System.cmd("mix", [task],
               cd: app_path,
               env: [{"MIX_ENV", "dev"}],
               stderr_to_stdout: true
             ) do
          {output, 0} -> Mix.shell().info(output)
          {_output, _} -> Mix.shell().info("  (skipped — dependency or compilation issue)")
        end
      end
    end)
  end

  defp has_boundary_compiler?(mix_file) do
    mix_file
    |> File.read!()
    |> String.contains?(":boundary")
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    []
  end
end
