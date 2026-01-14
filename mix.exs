defmodule Perme8.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      listeners: [Phoenix.CodeReloader],
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: [
        precommit: :test,
        "assets.build": :dev,
        "assets.deploy": :prod
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
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind jarga", "assets.copy_fonts", "esbuild jarga"],
      "assets.deploy": [
        "tailwind jarga --minify",
        "assets.copy_fonts",
        "esbuild jarga --minify",
        "phx.digest"
      ],
      precommit: [
        "compile --warning-as-errors",
        "deps.unlock --unused",
        "format --check-formatted",
        "credo --strict",
        "step_linter",
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

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    []
  end
end
