defmodule JargaWeb.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """

  @apps [:jarga, :identity]

  def migrate do
    load_apps()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_apps()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Enum.flat_map(@apps, fn app ->
      Application.fetch_env!(app, :ecto_repos)
    end)
  end

  defp load_apps do
    Application.ensure_all_started(:ssl)

    for app <- @apps do
      Application.ensure_loaded(app)
    end
  end
end
