defmodule Alkali.Application.Behaviours.ConfigLoaderBehaviour do
  @moduledoc """
  Behaviour defining the configuration loader interface.

  This behaviour abstracts configuration loading operations, allowing the
  application layer to depend on abstractions rather than concrete
  infrastructure implementations.

  ## Usage

  Infrastructure implementations should implement this behaviour:

      defmodule Alkali.Infrastructure.ConfigLoader do
        @behaviour Alkali.Application.Behaviours.ConfigLoaderBehaviour

        @impl true
        def load(site_path), do: # implementation
      end

  Use cases should accept the implementation via options:

      def execute(site_path, opts \\\\ []) do
        config_loader = Keyword.get(opts, :config_loader, Alkali.Infrastructure.ConfigLoader)
        config_loader.load(site_path)
      end
  """

  @type config :: map()

  @doc """
  Loads site configuration from the config file.

  ## Parameters

    - `site_path` - Path to the site directory containing config/alkali.exs
    - `opts` - Optional keyword list with:
      - `:file_system` - Module for file operations (default: File)

  ## Returns

    - `{:ok, map()}` with configuration on success
    - `{:error, String.t()}` on failure
  """
  @callback load(String.t(), keyword()) :: {:ok, config()} | {:error, String.t()}
end
