defmodule Jarga.Repo do
  use Ecto.Repo,
    otp_app: :jarga,
    adapter: Ecto.Adapters.Postgres
end
