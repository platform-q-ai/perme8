defmodule Agents.Repo do
  @moduledoc """
  Ecto repository for the Agents app.

  Connects to the same database as Jarga.Repo and Identity.Repo
  but allows the Agents bounded context to be self-contained
  without depending on other apps for persistence.
  """

  # Shared infrastructure - can be used by all Agents modules
  use Boundary, top_level?: true, deps: []

  use Ecto.Repo,
    otp_app: :agents,
    adapter: Ecto.Adapters.Postgres
end
