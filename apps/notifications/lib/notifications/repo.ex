defmodule Notifications.Repo do
  @moduledoc """
  Ecto repository for the Notifications app.

  Connects to the same database as Jarga.Repo, Identity.Repo, and Agents.Repo
  but allows the Notifications bounded context to be self-contained
  without depending on other apps for persistence.
  """

  # Shared infrastructure - can be used by all Notifications modules
  use Boundary, top_level?: true, deps: []

  use Ecto.Repo,
    otp_app: :notifications,
    adapter: Ecto.Adapters.Postgres
end
