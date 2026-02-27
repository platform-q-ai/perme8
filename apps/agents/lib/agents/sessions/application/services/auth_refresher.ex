defmodule Agents.Sessions.Application.Services.AuthRefresher do
  @moduledoc """
  Reads the host's opencode `auth.json` and pushes fresh credentials
  to a running opencode server via its `PUT /auth/:id` API.

  This enables long-running containers to survive OAuth token expiry
  without being destroyed and recreated.

  ## How it works

  1. Reads the host's `auth.json` (the same file used by `SessionsConfig.container_env/0`)
  2. Parses each provider's credentials
  3. Pushes each provider to the running opencode server via `PUT /auth/:id`

  ## auth.json format

  The file contains a map of provider IDs to credential objects:

      {
        "anthropic": {"type": "oauth", "access": "...", "refresh": "...", "expires": 1234567890},
        "openrouter": {"type": "api", "key": "sk-or-..."}
      }

  Each provider's credentials are sent as-is to the opencode server.
  """

  require Logger

  @auth_json_path Path.expand("~/.local/share/opencode/auth.json")

  @doc """
  Refresh authentication for all providers on a running opencode server.

  Reads the host's `auth.json`, parses each provider, and calls
  `PUT /auth/:provider_id` on the opencode server.

  Returns `{:ok, refreshed_providers}` with a list of provider IDs
  that were successfully refreshed, or `{:error, reason}` if the
  auth.json could not be read or parsed.

  ## Options

    * `:auth_json_path` - Override the path to auth.json (for testing)
    * `:file_reader` - Module implementing `read/1` (defaults to `File`)
  """
  @spec refresh_auth(String.t(), module(), keyword()) ::
          {:ok, [String.t()]} | {:error, term()}
  def refresh_auth(base_url, opencode_client, opts \\ []) do
    path = Keyword.get(opts, :auth_json_path, @auth_json_path)
    file_reader = Keyword.get(opts, :file_reader, File)
    http_opts = Keyword.take(opts, [:http])

    with {:ok, contents} <- file_reader.read(path),
         {:ok, providers} <- Jason.decode(contents) do
      results =
        Enum.map(providers, fn {provider_id, credentials} ->
          case opencode_client.set_auth(base_url, provider_id, credentials, http_opts) do
            {:ok, _} ->
              Logger.info("AuthRefresher: refreshed auth for provider '#{provider_id}'")
              {:ok, provider_id}

            {:error, reason} ->
              Logger.warning(
                "AuthRefresher: failed to refresh '#{provider_id}': #{inspect(reason)}"
              )

              {:error, provider_id, reason}
          end
        end)

      refreshed = for {:ok, id} <- results, do: id
      {:ok, refreshed}
    else
      {:error, reason} ->
        Logger.warning("AuthRefresher: failed to read auth.json: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Check which providers are currently connected on the opencode server.

  Calls `GET /provider` and returns the list of connected provider IDs.
  """
  @spec connected_providers(String.t(), module(), keyword()) ::
          {:ok, [String.t()]} | {:error, term()}
  def connected_providers(base_url, opencode_client, opts \\ []) do
    http_opts = Keyword.take(opts, [:http])

    case opencode_client.list_providers(base_url, http_opts) do
      {:ok, %{"connected" => connected}} when is_list(connected) ->
        {:ok, connected}

      {:ok, _body} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
