defmodule Agents.Tickets.Application do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [Agents.Tickets.Domain, Agents.Tickets.Infrastructure, Perme8.Events],
    exports: [TicketsConfig, UseCases.RecordStageTransition]
end
