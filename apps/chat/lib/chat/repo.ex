defmodule Chat.Repo do
  @moduledoc """
  Ecto repository for the Chat app.
  """

  use Boundary, top_level?: true, deps: []

  use Ecto.Repo,
    otp_app: :chat,
    adapter: Ecto.Adapters.Postgres
end
