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
    quote do
      providers = Application.compile_env(:agents, :mcp_tool_providers, [])

      for provider <- providers do
        Code.ensure_compiled!(provider)

        unless function_exported?(provider, :components, 0) do
          raise CompileError,
            description: "#{inspect(provider)} does not implement ToolProvider.components/0"
        end

        for {mod, name} <- provider.components() do
          component(mod, name: name)
        end
      end
    end
  end
end
