defmodule StaticSite.Infrastructure.ConfigLoader do
  @moduledoc """
  Loads site configuration from config/static_site.exs file.
  """

  @doc """
  Loads site configuration from the config file.

  ## Parameters
    - `site_path` - Path to the site directory containing config/static_site.exs

  ## Returns
    - `{:ok, map()}` with configuration on success
    - `{:error, String.t()}` on failure
  """
  @spec load(String.t()) :: {:ok, map()} | {:error, String.t()}
  def load(site_path) do
    config_file = Path.join([site_path, "config", "static_site.exs"])

    if File.exists?(config_file) do
      load_config_file(config_file, site_path)
    else
      # Return default config if file doesn't exist
      {:ok, default_config(site_path)}
    end
  end

  defp load_config_file(config_file, site_path) do
    try do
      # Use Config.Reader to read the config file properly
      config_data = Config.Reader.read!(config_file)

      # Extract the :static_site config
      static_site_config =
        case Keyword.get(config_data, :static_site) do
          nil ->
            # If no :static_site key, return default
            default_config(site_path)

          opts when is_list(opts) ->
            Enum.into(opts, %{})

          opts when is_map(opts) ->
            opts
        end

      # Merge with required paths
      config =
        static_site_config
        |> Map.put_new(:site_path, site_path)
        |> Map.put_new(:content_path, "content")
        |> Map.put_new(:output_path, "_site")
        |> Map.put_new(:assets_path, "assets")
        |> Map.put_new(:layouts_path, "layouts")
        |> normalize_site_config()

      {:ok, config}
    rescue
      e ->
        {:error, "Failed to load config file #{config_file}: #{Exception.message(e)}"}
    end
  end

  defp normalize_site_config(config) do
    # If there's a :site key with nested config, merge it to top level for easier access
    # while keeping the original :site key for template access
    if Map.has_key?(config, :site) do
      site_data = Map.get(config, :site)

      config
      |> Map.put_new(:site_name, Map.get(site_data, :title, "My Site"))
      |> Map.put_new(:site_url, Map.get(site_data, :url, "http://localhost"))
      |> Map.put_new(:site_author, Map.get(site_data, :author, "Anonymous"))
    else
      # If no :site key, create one from top-level keys
      site_data = %{
        title: Map.get(config, :site_name, "My Site"),
        url: Map.get(config, :site_url, "http://localhost"),
        author: Map.get(config, :site_author, "Anonymous")
      }

      Map.put(config, :site, site_data)
    end
  end

  defp default_config(site_path) do
    %{
      site: %{
        title: "My Site",
        url: "http://localhost",
        author: "Anonymous"
      },
      site_name: "My Site",
      site_url: "http://localhost",
      site_author: "Anonymous",
      content_path: "content",
      output_path: "_site",
      assets_path: "assets",
      layouts_path: "layouts",
      site_path: site_path
    }
  end
end
