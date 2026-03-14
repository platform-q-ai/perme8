defmodule EntityRelationshipManager.Infrastructure.Adapters.Neo4jAdapter.BoltxAdapter do
  @moduledoc """
  Real Neo4j adapter using the Neo4j HTTP Transactional API.

  Executes Cypher queries against a running Neo4j instance over HTTP.
  No external Bolt driver dependency is required — uses `Req` for HTTP
  requests.

  Despite the module name (kept for consistency with existing references),
  this adapter communicates over HTTP, not Bolt.

  ## Configuration

      config :entity_relationship_manager, :neo4j,
        url: "http://localhost:7474",
        auth: [username: "neo4j", password: "password"],
        database: "neo4j"
  """

  @doc """
  Execute a parameterized Cypher query against Neo4j.

  Returns `{:ok, %{records: list(), summary: map()}}` on success,
  or `{:error, reason}` on failure.
  """
  @spec execute(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def execute(cypher, params) do
    config = Application.get_env(:entity_relationship_manager, :neo4j, [])
    url = neo4j_url(config)
    database = Keyword.get(config, :database, "neo4j")
    auth_config = Keyword.get(config, :auth, [])

    username = Keyword.get(auth_config, :username, "neo4j")
    password = Keyword.get(auth_config, :password, "password")

    # Neo4j HTTP Transactional API: commit endpoint runs the query in an
    # auto-commit transaction.
    tx_url = "#{url}/db/#{database}/tx/commit"

    body = %{
      statements: [
        %{
          statement: cypher,
          parameters: params,
          resultDataContents: ["row"]
        }
      ]
    }

    case Req.post(tx_url,
           json: body,
           auth: {:basic, "#{username}:#{password}"},
           headers: [{"accept", "application/json"}]
         ) do
      {:ok, %Req.Response{status: 200, body: %{"results" => results, "errors" => []}}} ->
        records = parse_results(results)
        {:ok, %{records: records, summary: %{}}}

      {:ok, %Req.Response{status: 200, body: %{"errors" => [error | _]}}} ->
        {:error, {:neo4j_error, error["message"] || inspect(error)}}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:connection_error, reason}}
    end
  end

  # Parse the Neo4j HTTP API response format into a list of maps
  # matching the format expected by GraphRepository:
  #   [%{"column1" => value1, "column2" => value2}, ...]
  defp parse_results([]), do: []

  defp parse_results([%{"columns" => columns, "data" => data} | _]) do
    Enum.map(data, fn %{"row" => row} ->
      columns
      |> Enum.zip(row)
      |> Map.new()
    end)
  end

  # Build the Neo4j HTTP base URL from config.
  # Supports both :url (http://host:port) and :uri (bolt://host:port) formats.
  defp neo4j_url(config) do
    cond do
      url = Keyword.get(config, :url) ->
        String.trim_trailing(url, "/")

      uri = Keyword.get(config, :uri) ->
        # Convert bolt:// URI to http(s):// URL.
        # bolt+s:// and bolt+ssc:// indicate TLS — map to https with port 7473.
        # Plain bolt:// maps to http with port 7474.
        {scheme, port} =
          cond do
            String.match?(uri, ~r"^bolt\+s(sc)?://") -> {"https", "7473"}
            true -> {"http", "7474"}
          end

        uri
        |> String.replace(~r"^bolt(\+s(?:sc)?)?://", "#{scheme}://")
        |> String.replace(~r":7687$", ":#{port}")
        |> String.trim_trailing("/")

      true ->
        "http://localhost:7474"
    end
  end
end
