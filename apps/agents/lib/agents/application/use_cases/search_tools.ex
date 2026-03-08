defmodule Agents.Application.UseCases.SearchTools do
  @moduledoc """
  Discovers and searches registered MCP tools across all configured tool providers.

  Supports listing all tools, filtering by keyword (matched against tool name and
  description, case-insensitive), and grouping results by provider.

  This use case does not require a user/workspace context because tool discovery
  is a server-level capability — all authenticated callers see the same tool catalog.
  """

  require Logger

  alias Agents.Application.GatewayConfig

  @type tool_info :: %{
          name: String.t(),
          description: String.t() | nil,
          input_schema: map() | nil
        }

  @type provider_group :: %{
          provider: String.t(),
          tools: [tool_info()]
        }

  @type result :: {:ok, [tool_info()]} | {:ok, [provider_group()]}

  @doc """
  Executes a tool search across all configured MCP tool providers.

  ## Options

    * `:query` - Optional keyword to filter tools by name or description (case-insensitive).
    * `:group_by_provider` - When `true`, results are grouped by provider name.
    * `:providers` - Override the list of provider modules (for testing).

  ## Returns

    * `{:ok, tools}` - A flat list of matching tool info maps.
    * `{:ok, groups}` - When `group_by_provider` is `true`, a list of provider groups.
  """
  @spec execute(map(), keyword()) :: result()
  def execute(params \\ %{}, opts \\ []) do
    query = Map.get(params, :query)
    group_by_provider = Map.get(params, :group_by_provider, false)
    providers = Keyword.get(opts, :providers, default_providers())

    if group_by_provider do
      {:ok, search_grouped(providers, query)}
    else
      {:ok, search_flat(providers, query)}
    end
  end

  defp search_flat(providers, query) do
    providers
    |> Enum.flat_map(&provider_tools/1)
    |> filter_by_query(query)
  end

  defp search_grouped(providers, query) do
    providers
    |> Enum.map(fn provider ->
      tools =
        provider
        |> provider_tools()
        |> filter_by_query(query)

      %{provider: provider_name(provider), tools: tools}
    end)
    |> Enum.reject(fn group -> group.tools == [] end)
  end

  defp provider_tools(provider) do
    case Code.ensure_loaded(provider) do
      {:module, _} ->
        Enum.flat_map(provider.components(), &load_tool/1)

      {:error, reason} ->
        Logger.warning("Skipping provider #{inspect(provider)}: failed to load (#{reason})")
        []
    end
  end

  defp load_tool({mod, name}) do
    case Code.ensure_loaded(mod) do
      {:module, _} ->
        [%{name: name, description: get_description(mod), input_schema: get_input_schema(mod)}]

      {:error, reason} ->
        Logger.warning("Skipping tool #{name}: #{inspect(mod)} failed to load (#{reason})")
        []
    end
  end

  defp get_description(mod) do
    case Code.fetch_docs(mod) do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} -> moduledoc
      {:docs_v1, _, _, _, :none, _, _} -> nil
      _ -> nil
    end
  end

  defp get_input_schema(mod) do
    if function_exported?(mod, :input_schema, 0) do
      mod.input_schema()
    else
      nil
    end
  end

  defp filter_by_query(tools, nil), do: tools
  defp filter_by_query(tools, ""), do: tools

  defp filter_by_query(tools, query) do
    downcased = String.downcase(query)

    Enum.filter(tools, fn tool ->
      matches_name?(tool.name, downcased) or matches_description?(tool.description, downcased)
    end)
  end

  defp matches_name?(name, query), do: String.contains?(String.downcase(name), query)

  defp matches_description?(nil, _query), do: false

  defp matches_description?(description, query),
    do: String.contains?(String.downcase(description), query)

  defp provider_name(provider) do
    provider |> Module.split() |> List.last()
  end

  defp default_providers do
    GatewayConfig.tool_providers()
  end
end
