defmodule Agents.Tickets.Application do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [Agents.Tickets.Domain],
    exports: [TicketsConfig]
end
