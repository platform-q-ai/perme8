defmodule Perme8Events do
  @moduledoc false

  # OTP application container — the public API is `Perme8.Events`.
  # This boundary exists only to satisfy Boundary's requirement that
  # every module belongs to a boundary.
  use Boundary,
    top_level?: true,
    deps: [],
    exports: []
end
