defmodule Agents.Pipeline.Application do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [Agents.Pipeline.Domain, Agents.Pipeline.Infrastructure],
    exports: [
      UseCases.LoadPipeline
    ]
end
