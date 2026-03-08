defmodule Agents.Infrastructure.Mcp.Tools.ToolsSearchTool do
  @moduledoc "Search and discover MCP tools available on the perme8-mcp server."

  use Hermes.Server.Component, type: :tool

  require Logger

  alias Hermes.Server.Response
  alias Agents.Infrastructure.Mcp.PermissionGuard
  alias Agents.Application.UseCases.SearchTools

  schema do
    field(:query, :string, description: "Optional keyword to filter tools by name or description")

    field(:group_by_provider, :boolean, description: "When true, group results by tool provider")
  end

  @impl true
  def execute(params, frame) do
    case PermissionGuard.check_permission(frame, "tools.search") do
      :ok ->
        search_params = %{
          query: Map.get(params, :query),
          group_by_provider: Map.get(params, :group_by_provider, false)
        }

        search_tools(search_params, frame)

      {:error, scope} ->
        {:reply, Response.error(Response.tool(), "Insufficient permissions: #{scope} required"),
         frame}
    end
  end

  defp search_tools(search_params, frame) do
    case SearchTools.execute(search_params) do
      {:ok, []} ->
        {:reply, Response.text(Response.tool(), "No tools found."), frame}

      {:ok, results} ->
        text = format_results(results, search_params.group_by_provider)
        {:reply, Response.text(Response.tool(), text), frame}
    end
  rescue
    error ->
      Logger.error("tools.search unexpected error: #{Exception.message(error)}")

      {:reply,
       Response.error(
         Response.tool(),
         "An unexpected error occurred while searching tools."
       ), frame}
  end

  defp format_results(results, true) do
    results
    |> Enum.map_join("\n\n", fn group ->
      header = "## #{group.provider}\n"
      tools = format_tool_list(group.tools)
      header <> tools
    end)
  end

  defp format_results(tools, false) do
    format_tool_list(tools)
  end

  defp format_tool_list(tools) do
    tools
    |> Enum.map_join("\n\n", fn tool ->
      description = tool.description || "No description available."
      schema_text = format_schema(tool.input_schema)

      """
      ### #{tool.name}
      **Description:** #{description}
      **Parameters:** #{schema_text}\
      """
    end)
  end

  defp format_schema(nil), do: "None"
  defp format_schema(schema) when schema == %{}, do: "None"

  defp format_schema(schema) do
    properties = Map.get(schema, "properties", %{})
    required = Map.get(schema, "required", [])

    format_properties(properties, required)
  end

  defp format_properties(properties, _required) when properties == %{}, do: "None"

  defp format_properties(properties, required) do
    Enum.map_join(properties, ", ", fn {name, details} ->
      type = Map.get(details, "type", "any")
      req = if name in required, do: " (required)", else: " (optional)"
      "#{name}: #{type}#{req}"
    end)
  end
end
