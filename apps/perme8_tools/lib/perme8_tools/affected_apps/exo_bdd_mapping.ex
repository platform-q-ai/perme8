defmodule Perme8Tools.AffectedApps.ExoBddMapping do
  @moduledoc """
  Maps affected umbrella apps to their exo-bdd config+domain test combos.

  Encodes the same domain-to-surface mapping as the CI Python script,
  ensuring a single source of truth for which exo-bdd tests to run
  when a given app changes.
  """

  @type combo :: %{
          app: String.t(),
          domain: String.t(),
          config_name: String.t(),
          timeout: pos_integer()
        }

  @all_combos [
    %{app: "agents", domain: "http", config_name: "agents", timeout: 10},
    %{app: "agents", domain: "security", config_name: "agents", timeout: 15},
    %{app: "agents-api", domain: "http", config_name: "agents-api", timeout: 10},
    %{app: "agents-api", domain: "security", config_name: "agents-api", timeout: 15},
    %{app: "agents-web", domain: "browser", config_name: "agents-web", timeout: 15},
    %{app: "agents-web", domain: "security", config_name: "agents-web", timeout: 15},
    %{app: "alkali", domain: "cli", config_name: "alkali", timeout: 5},
    %{app: "erm", domain: "http", config_name: "entity-relationship-manager", timeout: 10},
    %{app: "erm", domain: "security", config_name: "entity-relationship-manager", timeout: 15},
    %{app: "identity", domain: "browser", config_name: "identity", timeout: 15},
    %{app: "identity", domain: "security", config_name: "identity", timeout: 20},
    %{app: "jarga-api", domain: "http", config_name: "jarga-api", timeout: 10},
    %{app: "jarga-api", domain: "security", config_name: "jarga-api", timeout: 15},
    %{app: "jarga-web", domain: "browser", config_name: "jarga-web", timeout: 15},
    %{app: "jarga-web", domain: "security", config_name: "jarga-web", timeout: 15},
    %{app: "exo-dashboard", domain: "browser", config_name: "exo-dashboard", timeout: 10},
    %{app: "webhooks-api", domain: "http", config_name: "webhooks-api", timeout: 10},
    %{app: "webhooks-api", domain: "security", config_name: "webhooks-api", timeout: 15}
  ]

  # Domain apps that fan out to their surface apps for exo-bdd testing
  @fan_out %{
    jarga: ["jarga-web", "jarga-api", "erm"],
    webhooks: ["webhooks-api"]
  }

  # Direct mapping: umbrella app atom -> exo-bdd app name string
  @app_to_exo_app %{
    agents: "agents",
    agents_api: "agents-api",
    agents_web: "agents-web",
    alkali: "alkali",
    entity_relationship_manager: "erm",
    identity: "identity",
    jarga_api: "jarga-api",
    jarga_web: "jarga-web",
    exo_dashboard: "exo-dashboard",
    webhooks_api: "webhooks-api"
  }

  @doc """
  Returns the complete list of all exo-bdd combos, matching the CI ALL_COMBOS.
  """
  @spec all_combos() :: [combo()]
  def all_combos, do: @all_combos

  @doc """
  Returns the exo-bdd combos for the given set of affected apps.

  ## Options

  - `:all_exo_bdd?` - if `true`, returns all combos regardless of affected apps
  """
  @spec exo_bdd_combos(MapSet.t(atom()), keyword()) :: [combo()]
  def exo_bdd_combos(affected_apps, opts \\ []) do
    if Keyword.get(opts, :all_exo_bdd?, false) do
      @all_combos
    else
      exo_app_names = resolve_exo_app_names(affected_apps)

      @all_combos
      |> Enum.filter(fn combo -> combo.app in exo_app_names end)
      |> Enum.uniq()
    end
  end

  # --- Private ---

  defp resolve_exo_app_names(affected_apps) do
    affected_apps
    |> Enum.flat_map(fn app ->
      fan_out_names = Map.get(@fan_out, app, [])
      direct_name = Map.get(@app_to_exo_app, app)

      case {fan_out_names, direct_name} do
        {[], nil} -> []
        {[], name} -> [name]
        {names, nil} -> names
        {names, name} -> [name | names]
      end
    end)
    |> Enum.uniq()
  end
end
