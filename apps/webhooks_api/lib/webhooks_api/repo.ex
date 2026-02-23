defmodule WebhooksApi.Repo do
  use Ecto.Repo, otp_app: :webhooks_api, adapter: Ecto.Adapters.Postgres

  use Boundary, top_level?: true, deps: [], exports: []
end
