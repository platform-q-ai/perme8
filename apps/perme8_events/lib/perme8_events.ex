defmodule Perme8Events do
  @moduledoc """
  Internal application module for perme8_events.

  The public API is provided by `Perme8.Events` (the facade module).
  This module exists only as the OTP application container.
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: []
end
