defmodule Agents.Infrastructure.Mcp.ToolProvider.Loader do
  @moduledoc """
  Compile-time macro that reads configured tool providers and emits
  `component()` calls for each tool they provide.

  ## Usage

  In your Hermes.Server module:

      defmodule MyServer do
        use Hermes.Server, name: "perme8-mcp", version: "1.0.0", capabilities: [:tools]
        use Agents.Infrastructure.Mcp.ToolProvider.Loader
      end

  ## Configuration

      config :agents, :mcp_tool_providers, [
        Agents.Infrastructure.Mcp.ToolProviders.KnowledgeToolProvider,
        Agents.Infrastructure.Mcp.ToolProviders.JargaToolProvider
      ]
  """

  defmacro __using__(_opts) do
    providers = Application.get_env(:agents, :mcp_tool_providers, [])

    component_calls =
      providers
      |> Enum.flat_map(fn provider -> provider.components() end)
      |> Enum.map(fn {mod, name} ->
        quote do
          component(unquote(mod), name: unquote(name))
        end
      end)

    quote do
      (unquote_splicing(component_calls))
    end
  end
end
