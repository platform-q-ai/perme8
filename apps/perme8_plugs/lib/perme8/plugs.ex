defmodule Perme8.Plugs do
  @moduledoc "Shared Plug infrastructure for the Perme8 umbrella."

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [SecurityHeaders]
end
