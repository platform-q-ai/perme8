defmodule Agents.Pipeline.Infrastructure do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [Agents.Pipeline.Domain],
    exports: [
      YamlParser
    ]
end
