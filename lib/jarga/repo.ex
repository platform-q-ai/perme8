defmodule Jarga.Repo do
  # Shared infrastructure - can be used by all contexts
  # Cannot depend on contexts or web layer
  use Boundary, top_level?: true, deps: []

  use Ecto.Repo,
    otp_app: :jarga,
    adapter: Ecto.Adapters.Postgres
end
