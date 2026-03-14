defmodule Perme8Tools.AffectedApps.FileClassifier do
  @moduledoc """
  Classifies changed file paths into their owning app and category.

  Handles shared config files, exo-bdd framework changes, non-code files,
  and app-specific code/test files.
  """

  @type classification ::
          {:app, atom(), :code | :test}
          | :all_apps
          | :all_exo_bdd
          | :ignore

  @type classification_result :: %{
          directly_affected: MapSet.t(atom()),
          all_apps?: boolean(),
          all_exo_bdd?: boolean()
        }

  @code_extensions ~w(.ex .exs .heex .ts .js .cjs .css .json .feature .po .pot .svg .png)

  @doc """
  Classifies a single changed file path.

  The `known_apps` list is used to validate that extracted app names
  actually exist in the umbrella.

  ## Returns

  - `{:app, app_name, :code}` - Code file in an app
  - `{:app, app_name, :test}` - Test file in an app
  - `:all_apps` - Shared config file (triggers all apps)
  - `:all_exo_bdd` - Exo-BDD framework file (triggers all exo-bdd tests)
  - `:ignore` - Non-code file or file outside tracked paths
  """
  @spec classify(String.t(), [atom()]) :: classification()
  def classify(file_path, known_apps) when is_binary(file_path) and is_list(known_apps) do
    cond do
      file_path == "" ->
        :ignore

      shared_config?(file_path) ->
        :all_apps

      exo_bdd_framework?(file_path) ->
        :all_exo_bdd

      ignored_path?(file_path) ->
        :ignore

      true ->
        classify_app_file(file_path, known_apps)
    end
  end

  @doc """
  Classifies a list of changed file paths and aggregates the results.

  Returns a map with:
  - `:directly_affected` - set of app atoms that have changed code/test files
  - `:all_apps?` - whether any shared config file changed
  - `:all_exo_bdd?` - whether the exo-bdd framework changed
  """
  @spec classify_all([String.t()], [atom()]) :: classification_result()
  def classify_all(file_paths, known_apps) when is_list(file_paths) and is_list(known_apps) do
    Enum.reduce(
      file_paths,
      %{directly_affected: MapSet.new(), all_apps?: false, all_exo_bdd?: false},
      fn path, acc ->
        case classify(path, known_apps) do
          {:app, app, _type} ->
            %{acc | directly_affected: MapSet.put(acc.directly_affected, app)}

          :all_apps ->
            %{acc | all_apps?: true}

          :all_exo_bdd ->
            %{acc | all_exo_bdd?: true}

          :ignore ->
            acc
        end
      end
    )
  end

  # --- Private ---

  defp shared_config?(path) do
    String.starts_with?(path, "config/") or
      path == "mix.exs" or
      path == "mix.lock" or
      path == ".tool-versions" or
      path == ".formatter.exs"
  end

  defp exo_bdd_framework?(path) do
    String.starts_with?(path, "tools/exo-bdd/")
  end

  defp ignored_path?(path) do
    String.starts_with?(path, "docs/") or
      String.starts_with?(path, "scripts/") or
      String.starts_with?(path, ".github/")
  end

  defp classify_app_file(path, known_apps) do
    with [_full, app_dir, rest] <- Regex.run(~r{^apps/([^/]+)/(.+)$}, path),
         app_atom = String.to_atom(app_dir),
         true <- app_atom in known_apps and code_file?(rest) do
      type = if String.starts_with?(rest, "test/"), do: :test, else: :code
      {:app, app_atom, type}
    else
      _ -> :ignore
    end
  end

  defp code_file?(path) do
    ext = Path.extname(path)
    ext in @code_extensions
  end
end
